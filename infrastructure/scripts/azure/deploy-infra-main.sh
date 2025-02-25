#!/bin/bash
# shellcheck disable=SC1091
set -ue

# Import utils functions
source ./utils/helpers.sh
source ./utils/requirements.sh
source ./iot/deploy-iot-ops.sh

#--------------------------------------------------------------
# PARSE COMMAND-LINE ARGUMENTS
#--------------------------------------------------------------

# Initialize variables (inputs)
INSTALL_REQUIREMENTS=false
INSTALL_PROXY=false
INSTALL_IOT_OPERATIONS=false
TARGET_ENVIRONMENT="development"
AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID=""

SUPPORTED_ENVIRONMENTS=("development")

# Function to display usage information
usage() {
    echo "Usage: $0 [-e environment] -o custom_locations_rp_object_id [--install-requirements] [--install-proxy] [--install-iot-operations] [--verbose]"
    exit 1
}

# Function to parse command-line arguments
parseArguments() {
    while getopts ":e:o:-:" opt; do
        case ${opt} in
        -) case "${OPTARG}" in
            install-requirements)
                INSTALL_REQUIREMENTS=true
                ;;
            install-proxy)
                INSTALL_PROXY=true
                ;;
            install-iot-operations)
                INSTALL_IOT_OPERATIONS=true
                ;;
            verbose) set -x ;;
            *) usage ;;
            esac ;;
        e) TARGET_ENVIRONMENT="${OPTARG}" ;;
        o) AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID=$OPTARG ;;
        \?) usage ;;
        esac
    done
}

parseArguments "$@"

#--------------------------------------------------------------
# ENVIRONMENT PARAMETERS
#--------------------------------------------------------------

logProgress "Getting the environment parameters..."

if ! [[ " ${SUPPORTED_ENVIRONMENTS[*]} " == *" ${TARGET_ENVIRONMENT} "* ]]; then
    logError "The specified environment is not supported."
    exit 1
fi

# shellcheck disable=SC2034
BICEP_PATH="../../bicep"
ENVIRONMENT_PATH="${BICEP_PATH}/environments/${TARGET_ENVIRONMENT}"
COMMON_PARAMETERS_FILE="${ENVIRONMENT_PATH}/common.json"
NETWORK_PARAMETERS_FILE="${ENVIRONMENT_PATH}/network.json"

# Parsing parameters from the JSON file
LOCATION=$(jq -r '.parameters.location.value' "${COMMON_PARAMETERS_FILE}")
PREFIX=$(jq -r '.parameters.prefix.value' "${COMMON_PARAMETERS_FILE}")
ID=$(jq -r '.parameters.id.value' "${COMMON_PARAMETERS_FILE}")
ENVIRONMENT=$(jq -r '.parameters.environment.value' "${COMMON_PARAMETERS_FILE}")

# Exit if any of the values are empty
if [[ -z "${LOCATION}" || -z "${PREFIX}" || -z "${ID}" || -z "${ENVIRONMENT}" ]]; then
    logError "One or more required parameters are empty."
    exit 1
fi

logInfo "--------------------------------------------------------------"
logInfo "PARAMETERS"
logInfo "--------------------------------------------------------------"
logInfo "Location: ${LOCATION}"
logInfo "Prefix: ${PREFIX}"
logInfo "ID: ${ID}"
logInfo "Environment: ${ENVIRONMENT}"
logInfo "--------------------------------------------------------------"

#--------------------------------------------------------------
# SIGNED-IN IP ADDRESS
#--------------------------------------------------------------

logProgress "Getting the signed-in user IP address..."

# Get the IP address of the signed-in user
SIGNED_IN_USER_IP_ADDRESS=$(curl -s https://ifconfig.me/ip)
logInfo "Signed-in user IP address: ${SIGNED_IN_USER_IP_ADDRESS}"

#--------------------------------------------------------------
# REQUIREMENTS
#--------------------------------------------------------------

# Check and Install Infastructure requirements
if [ "${INSTALL_REQUIREMENTS}" = true ]; then
    checkRequirements
    exit 0
fi

#--------------------------------------------------------------
# IOT OPERATIONS
#--------------------------------------------------------------

# Check and Install IoT Operations
if [ "${INSTALL_IOT_OPERATIONS}" = true ]; then
    installIoTOperationsOnAllClusters
    exit 0
fi

#--------------------------------------------------------------
# FUNDAMENTALS
#--------------------------------------------------------------

logProgress "Deploying the fundamentals resources..."

FUNDAMENTALS_DEPLOYMENT_NAME="fundamentals"
FUNDAMENTALS_TEMPLATE_FILE="${BICEP_PATH}/fundamentals.bicep"
FUNDAMENTALS_PARAMETERS_FILE="${ENVIRONMENT_PATH}/fundamentals.json"

# Deploy the resources using the bicep template
az deployment sub create \
    --name "${FUNDAMENTALS_DEPLOYMENT_NAME}" \
    --location "${LOCATION}" \
    --template-file "${FUNDAMENTALS_TEMPLATE_FILE}" \
    --parameters "${COMMON_PARAMETERS_FILE}" \
    --parameters "${NETWORK_PARAMETERS_FILE}" \
    --parameters "${FUNDAMENTALS_PARAMETERS_FILE}" \
    --parameters \
        signedInPrincipalId="$(getSignedInPrincipalId)" \
        signedInPrincipalType="$(getSignedInPrincipalType)" \
        keyVaultIpRule="${SIGNED_IN_USER_IP_ADDRESS}"

# Get the outputs from the deployment
FUNDAMENTALS_DEPLOYMENT_OUTPUTS=$(az deployment sub show \
    --name "${FUNDAMENTALS_DEPLOYMENT_NAME}" \
    --query properties.outputs)

FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME=$(echo "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS}" | jq -r .keyVaultName.value)
checkDeploymentOutput FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME
FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_CLUSTER_ID=$(echo "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS}" | jq -r .managedIdentityClusterId.value)
checkDeploymentOutput FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_CLUSTER_ID
FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_PROXY_ID=$(echo "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS}" | jq -r .managedIdentityProxyId.value)
checkDeploymentOutput FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_PROXY_ID
FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_NAME=$(echo "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS}" | jq -r .vnetName.value)
checkDeploymentOutput FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_NAME
FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_RESOURCE_GROUP_NAME=$(echo "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS}" | jq -r .vnetResourceGroupName.value)
checkDeploymentOutput FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_RESOURCE_GROUP_NAME
FUNDAMENTALS_DEPLOYMENT_OUTPUTS_APP_CONFIGURATION_NAME=$(echo "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS}" | jq -r .appConfigurationName.value)
checkDeploymentOutput FUNDAMENTALS_DEPLOYMENT_OUTPUTS_APP_CONFIGURATION_NAME

#--------------------------------------------------------------
# SSH KEY PAIRS/PASSWORD
#--------------------------------------------------------------

logProgress "Generating SSH key pairs and password..."

storeSSHKeysInKeyVault "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME}"
storeProxyPasswordInKeyVault "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME}"

#--------------------------------------------------------------
# PROXIES
#--------------------------------------------------------------

if [ "${INSTALL_PROXY}" = true ]; then
    
    logProgress "Deploying the proxies virtual machines..."

    PROXIES_SCRIPTS_PATH="../proxy/" # Scripts at this location will be copied on VMs
    PROXIES_DEPLOYMENT_NAME="proxies"
    PROXIES_TEMPLATE_FILE="${BICEP_PATH}/proxies.bicep"
    PROXIES_PARAMETERS_FILE="${ENVIRONMENT_PATH}/proxies.json"

    # Get the parent proxy host from the parameters file
    PARENT_PROXY_HOST=$(jq -r '.parameters.network.value.subnets.corp.proxy.backPrivateIPAddress' "${NETWORK_PARAMETERS_FILE}")

    # Get the admin username from the parameters file
    PROXIES_VM_ADMIN_USERNAME=$(jq -r '.parameters.proxyAdminUserName.value' "${PROXIES_PARAMETERS_FILE}")
    PROXIES_CORP_VM_CMD="./deploy-proxy-main.sh -a ${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_APP_CONFIGURATION_NAME} --verbose"
    PROXIES_SITE_VM_CMD="./deploy-proxy-main.sh -a ${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_APP_CONFIGURATION_NAME} -h ${PARENT_PROXY_HOST} --verbose"

    az deployment sub create \
        --name "${PROXIES_DEPLOYMENT_NAME}" \
        --location "${LOCATION}" \
        --template-file "${PROXIES_TEMPLATE_FILE}" \
        --parameters "${COMMON_PARAMETERS_FILE}" \
        --parameters "${NETWORK_PARAMETERS_FILE}" \
        --parameters "${PROXIES_PARAMETERS_FILE}" \
        --parameters \
            proxyManagedIdentityId="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_PROXY_ID}" \
            proxyAdminPublicKey="$(getSecret "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME}" "SSH-PUBLIC-KEY")" \
            proxyCorpBase64Script="$(base64script "${PROXIES_VM_ADMIN_USERNAME}" "${PROXIES_CORP_VM_CMD}" "${PROXIES_SCRIPTS_PATH}")" \
            proxySiteBase64Script="$(base64script "${PROXIES_VM_ADMIN_USERNAME}" "${PROXIES_SITE_VM_CMD}" "${PROXIES_SCRIPTS_PATH}")" \
            vnetName="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_NAME}" \
            vnetResourceGroupName="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_RESOURCE_GROUP_NAME}"

    logProgress "Updating clusters to use proxy settings..."

    CLUSTERS_DEPLOYMENT_NAME="clusters"
    CLUSTERS_TEMPLATE_FILE="${BICEP_PATH}/clusters.bicep"
    CLUSTERS_PARAMETERS_FILE="${ENVIRONMENT_PATH}/clusters.json"

    # Get the admin username from the parameters file
    CLUSTERS_VM_ADMIN_USERNAME=$(jq -r '.parameters.clusterAdminUserName.value' "${CLUSTERS_PARAMETERS_FILE}")
    CLUSTERS_VM_CMD="./deploy-proxy-main.sh -a ${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_APP_CONFIGURATION_NAME} --configure-cluster --verbose"

    az deployment sub create \
        --name "${CLUSTERS_DEPLOYMENT_NAME}" \
        --location "${LOCATION}" \
        --template-file "${CLUSTERS_TEMPLATE_FILE}" \
        --parameters "${COMMON_PARAMETERS_FILE}" \
        --parameters "${NETWORK_PARAMETERS_FILE}" \
        --parameters "${CLUSTERS_PARAMETERS_FILE}" \
        --parameters \
            clusterManagedIdentityId="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_CLUSTER_ID}" \
            clusterAdminPublicKey="$(getSecret "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME}" "SSH-PUBLIC-KEY")" \
            clusterBase64Script="$(base64script "${CLUSTERS_VM_ADMIN_USERNAME}" "${CLUSTERS_VM_CMD}" "${PROXIES_SCRIPTS_PATH}")" \
            vnetName="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_NAME}" \
            vnetResourceGroupName="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_RESOURCE_GROUP_NAME}"
fi

#--------------------------------------------------------------
# CLUSTERS
#--------------------------------------------------------------

logProgress "Deploying the clusters virtual machines..."

if [ -z "${AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID}" ]; then
    logError "The custom locations RP object ID is empty."
    exit 1
fi

CLUSTERS_SCRIPTS_PATH="../cluster/" # Scripts at this location will be copied on VMs
CLUSTERS_DEPLOYMENT_NAME="clusters"
CLUSTERS_TEMPLATE_FILE="${BICEP_PATH}/clusters.bicep"
CLUSTERS_PARAMETERS_FILE="${ENVIRONMENT_PATH}/clusters.json"

# Get the admin username from the parameters file
CLUSTERS_VM_ADMIN_USERNAME=$(jq -r '.parameters.clusterAdminUserName.value' "${CLUSTERS_PARAMETERS_FILE}")
CLUSTERS_VM_CMD="./deploy-cluster-main.sh -a ${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_APP_CONFIGURATION_NAME} -o ${AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID} --verbose"

az deployment sub create \
    --name "${CLUSTERS_DEPLOYMENT_NAME}" \
    --location "${LOCATION}" \
    --template-file "${CLUSTERS_TEMPLATE_FILE}" \
    --parameters "${COMMON_PARAMETERS_FILE}" \
    --parameters "${NETWORK_PARAMETERS_FILE}" \
    --parameters "${CLUSTERS_PARAMETERS_FILE}" \
    --parameters \
        clusterManagedIdentityId="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_MANAGED_IDENTITY_CLUSTER_ID}" \
        clusterAdminPublicKey="$(getSecret "${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_KEYVAULT_NAME}" "SSH-PUBLIC-KEY")" \
        clusterBase64Script="$(base64script "${CLUSTERS_VM_ADMIN_USERNAME}" "${CLUSTERS_VM_CMD}" "${CLUSTERS_SCRIPTS_PATH}")" \
        vnetName="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_NAME}" \
        vnetResourceGroupName="${FUNDAMENTALS_DEPLOYMENT_OUTPUTS_VNET_RESOURCE_GROUP_NAME}"
