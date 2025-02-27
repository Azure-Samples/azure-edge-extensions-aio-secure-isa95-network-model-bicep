#!/bin/bash
# shellcheck disable=SC1091,SC2155
set -ue

# Import utils functions
source ./utils/helpers.sh
source ./utils/prerequisites.sh

#--------------------------------------------------------------
# PARSE COMMAND-LINE ARGUMENTS
#--------------------------------------------------------------

# Initialize variables (inputs)
AZURE_APP_CONFIGURATION_NAME=""
PARENT_PROXY_HOST=""
CONFIGURE_CLUSTER=false

# Initialize variables (others)
AZURE_VIRTUAL_MACHINE_NAME=$(hostname)

# Function to display usage information
usage() {
    echo "Usage: $0 -a app_configuration_name [-h parent_proxy_host] [--configure-cluster] [--verbose]"
    exit 1
}

# Function to parse command-line arguments
parseArguments() {
    while getopts ":-:a:h:" opt; do
        case ${opt} in
        -) case "${OPTARG}" in
            configure-cluster) CONFIGURE_CLUSTER=true ;;
            verbose) set -x ;;
            *) usage ;;
            esac ;;
        a) export AZURE_APP_CONFIGURATION_NAME=$OPTARG ;;
        h) PARENT_PROXY_HOST=$OPTARG ;;
        \?) usage ;;
        esac
    done

    # Validate required arguments
    if [ -z "${AZURE_APP_CONFIGURATION_NAME}" ]; then
        logError "All inputs parameters are required."
        usage
    fi
}

parseArguments "$@"

#--------------------------------------------------------------
# GENERAL INFORMATION
#--------------------------------------------------------------

logInfo "--------------------------------------------------"
logInfo "GENERAL INFORMATION"
logInfo "--------------------------------------------------"
logInfo "Cluster name: ${AZURE_VIRTUAL_MACHINE_NAME}"
logInfo "Current user: $(whoami)"
logInfo "--------------------------------------------------"

#--------------------------------------------------------------
# PRE-REQUISITES
#--------------------------------------------------------------

installPreRequisites

#--------------------------------------------------------------
# LOGIN TO AZURE
#--------------------------------------------------------------

loginWithManagedIdentity

AZURE_SUBSCRIPTION_ID=$(getSetting subscriptionId)
checkSetting AZURE_SUBSCRIPTION_ID
export AZURE_KEYVAULT_NAME=$(getSetting keyVaultName)
checkSetting AZURE_KEYVAULT_NAME
AZURE_ARC_RESOURCE_GROUP_NAME=$(getSetting arcResourceGroupName)
checkSetting AZURE_ARC_RESOURCE_GROUP_NAME

#--------------------------------------------------------------
# CONFIGURE CLUSTER
#--------------------------------------------------------------

if [ "${CONFIGURE_CLUSTER}" = true ]; then
    logProgress "Configuring cluster to use proxy..."

    # Get cluster name
    CLUSTER_NAME_UPPER=$(echo "${AZURE_VIRTUAL_MACHINE_NAME}" | tr '[:lower:]' '[:upper:]')

    # Get cluster proxy settings
    HTTP_PROXY=$(getSecret "${CLUSTER_NAME_UPPER}-HTTP-PROXY")
    checkSecret HTTP_PROXY
    HTTPS_PROXY=$(getSecret "${CLUSTER_NAME_UPPER}-HTTPS-PROXY")
    checkSecret HTTPS_PROXY
    NO_PROXY=$(getSecret "${CLUSTER_NAME_UPPER}-NO-PROXY")
    checkSecret NO_PROXY

    # Configure cluster proxy settings
    addEnvironmentVariable HTTP_PROXY "${HTTP_PROXY}"
    addEnvironmentVariable http_proxy "${HTTP_PROXY}"
    addEnvironmentVariable HTTPS_PROXY "${HTTPS_PROXY}"
    addEnvironmentVariable https_proxy "${HTTPS_PROXY}"
    addEnvironmentVariable NO_PROXY "${NO_PROXY}"
    addEnvironmentVariable no_proxy "${NO_PROXY}"

    # Configure apt to use the proxy
    logInfo "Configuring apt to use the proxy"
    cat <<APT_CONF | sudo tee /etc/apt/apt.conf.d/proxy
Acquire::http::Proxy "${HTTP_PROXY}";
Acquire::https::Proxy "${HTTPS_PROXY}";
APT_CONF

    logInfo "Installing connectedk8s Azure CLI extension..."
    az extension add --upgrade --name connectedk8s --allow-preview true --yes
    checkError

    logInfo "Checking if cluster ${AZURE_VIRTUAL_MACHINE_NAME} is already Arc connected..."
    ARC_CLUSTER_NAME=$(
        az connectedk8s show \
            --name "${AZURE_VIRTUAL_MACHINE_NAME}" \
            --resource-group "${AZURE_ARC_RESOURCE_GROUP_NAME}" \
            --subscription "${AZURE_SUBSCRIPTION_ID}" \
            --query name -o tsv
    ) || true

    if [ -n "${ARC_CLUSTER_NAME}" ]; then
        logInfo "Cluster ${AZURE_VIRTUAL_MACHINE_NAME} is already Arc connected."
        logInfo "Updating proxy settings..."
        az connectedk8s update \
            --name "${AZURE_VIRTUAL_MACHINE_NAME}" \
            --resource-group "${AZURE_ARC_RESOURCE_GROUP_NAME}" \
            --proxy-http "${HTTP_PROXY}" \
            --proxy-https "${HTTPS_PROXY}" \
            --proxy-skip-range "${NO_PROXY}"
        checkError
    fi

    logProgress "Cluster configured successfully."
    exit 0
fi

#--------------------------------------------------------------
# GET SETTINGS
#--------------------------------------------------------------

SETTINGS_PATH="./configuration/settings.yml"

PROXY_IP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PROXY_BROADCAST=$(ip -4 addr show eth1 | grep -oP '(?<=brd )\d+(\.\d+){3}')
PROXY_MASK="${PROXY_BROADCAST//.255/.0}/24"
HOSTNAME=$(hostname)

PROXY_PORT=$(yq '.proxy.port' "${SETTINGS_PATH}")
PROXY_USERNAME=$(yq '.proxy.username' "${SETTINGS_PATH}")
PROXY_PASSWORD=$(getSecret PROXY-PASSWORD)
checkSecret PROXY_PASSWORD

logInfo "--------------------------------------------------"
logInfo "SETTINGS"
logInfo "--------------------------------------------------"
logInfo "Proxy port: ${PROXY_PORT}"
logInfo "Proxy username: ${PROXY_USERNAME}"
logInfo "Proxy password: ${PROXY_PASSWORD}"
logInfo "Proxy IP: ${PROXY_IP}"
logInfo "Proxy broadcast: ${PROXY_BROADCAST}"
logInfo "Proxy mask: ${PROXY_MASK}"
logInfo "Hostname: ${HOSTNAME}"
logInfo "--------------------------------------------------"

#--------------------------------------------------------------
# INSTALL SQUID
#--------------------------------------------------------------

installSquid

#--------------------------------------------------------------
# CONFIGURE SQUID
#--------------------------------------------------------------

logProgress "Configuring squid..."

# Stop squid service
sudo service squid stop
checkError

ENDPOINTS_LIST_PATH="./configuration/endpoints-lists.yml"

cat <<ENDPOINTS | sudo tee "/etc/squid/endpoints.install.txt"
$(yq '.installEndpoints.[]' "${ENDPOINTS_LIST_PATH}")
ENDPOINTS

cat <<ENDPOINTS | sudo tee "/etc/squid/endpoints.arc.txt"
$(yq '.arcEndpoints.[]' "${ENDPOINTS_LIST_PATH}")
ENDPOINTS

cat <<ENDPOINTS | sudo tee "/etc/squid/endpoints.aio.txt"
$(yq '.aioEndpoints.[]' "${ENDPOINTS_LIST_PATH}")
ENDPOINTS

sudo mv /etc/squid/squid.conf /etc/squid/squid.conf.default
cat <<PROXY_CONF | sudo tee "/etc/squid/squid.conf"
visible_hostname ${HOSTNAME}

http_port ${PROXY_IP}:${PROXY_PORT} 

cache_dir ufs /var/spool/squid 100 16 256
# Max size of buffer to download file
client_request_buffer_max_size 10000 KB

#################################### ACL ####################################

acl all src all # ACL to authorize all networks (Source = All)  ACL mandaotry
acl lan src ${PROXY_MASK} # ACL to authorize backend network  ${PROXY_MASK}
acl Safe_ports port 80 # Port HTTP = Port 'sure'
acl Safe_ports port 443 # Port HTTPS = Port 'sure'
acl Safe_ports port 8084 # Used by .obo.arc.azure.com
acl Safe_ports port 8883 # Used by mqtt
acl Safe_ports port 18883 # Used by mqtt
acl Safe_ports port 18083 # Used by mqtt
############################################################################

# Disable all protocols and ports
http_access deny !Safe_ports

# deny  ; ! = except ; lan = acl name.
http_access deny !lan

# Port used by the proxy:
# http_port ${PROXY_PORT}

# list of dns domains 
acl installendpoints dstdomain "/etc/squid/endpoints.install.txt"
acl arcendpoints dstdomain "/etc/squid/endpoints.arc.txt"
acl aioendpoints dstdomain "/etc/squid/endpoints.aio.txt"
http_access allow installendpoints
http_access allow arcendpoints
http_access allow aioendpoints
http_access deny all

# Authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid proxy-caching web server
auth_param basic credentialsttl 2 hours
acl auth_users proxy_auth REQUIRED
http_access allow auth_users
PROXY_CONF

if [ -n "${PARENT_PROXY_HOST}" ]; then
    cat <<PARENT_PROXY_CONF | sudo tee -a "/etc/squid/squid.conf"
# Add Parent Proxy configuration
cache_peer ${PARENT_PROXY_HOST} parent ${PROXY_PORT} 0 default no-query no-digest login=PASSTHRU
acl internal_sites dstdomain .corp.contoso.com
always_direct allow internal_sites
never_direct allow all
PARENT_PROXY_CONF
fi

# Create password file
sudo htpasswd -bc /etc/squid/passwd "${PROXY_USERNAME}" "${PROXY_PASSWORD}"
checkError

# Restart squid service
sudo service squid restart
checkError

logProgress "Squid proxy configured successfully."

HTTP_PROXY="http://${PROXY_USERNAME}:${PROXY_PASSWORD}@${PROXY_IP}:${PROXY_PORT}"                                                              # DevSkim: ignore DS137138, DS162092
HTTPS_PROXY="http://${PROXY_USERNAME}:${PROXY_PASSWORD}@${PROXY_IP}:${PROXY_PORT}"                                                             # DevSkim: ignore DS137138, DS162092
NO_PROXY="localhost,127.0.0.1,.svc,.svc.cluster.local,172.16.0.0/12,192.168.0.0/16,169.254.169.254,logcollector,${PROXY_MASK}/24,10.43.0.0/16" # DevSkim: ignore DS162092

logInfo "Client configuration:"
logInfo "export HTTP_PROXY=${HTTP_PROXY}"
logInfo "export HTTPS_PROXY=${HTTPS_PROXY}"
logInfo "export NO_PROXY=${NO_PROXY}"
logInfo "export http_proxy=${HTTP_PROXY}"
logInfo "export https_proxy=${HTTPS_PROXY}"
logInfo "export no_proxy=${NO_PROXY}"

PROXY_NAME_UPPER=$(echo "${AZURE_VIRTUAL_MACHINE_NAME}" | tr '[:lower:]' '[:upper:]')
CLUSTER_NAME_CLUSTER=${PROXY_NAME_UPPER//PROXY/CLUSTER}

createOrUpdateSecret "${CLUSTER_NAME_CLUSTER}-HTTP-PROXY" "${HTTP_PROXY}"
createOrUpdateSecret "${CLUSTER_NAME_CLUSTER}-HTTPS-PROXY" "${HTTPS_PROXY}"
createOrUpdateSecret "${CLUSTER_NAME_CLUSTER}-NO-PROXY" "${NO_PROXY}"
