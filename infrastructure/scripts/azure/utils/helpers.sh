#!/bin/bash
# shellcheck disable=SC2155

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

#--------------------------------------------------------------
# LOG FUNCTIONS
#--------------------------------------------------------------

COLOR_BLUE='\033[0;34m'   # Blue
COLOR_YELLOW='\033[0;33m' # Yellow
COLOR_GREEN='\033[0;32m'  # Green
COLOR_RED='\033[0;31m'    # Red
COLOR_NC='\033[0m'        # No Color

# shellcheck disable=SC2034
CHECK_MARK='\u2714' # Check mark
# shellcheck disable=SC2034
CROSS_MARK='\u2718' # Cross mark

logInfo() {
    echo -e "${COLOR_GREEN}$1${COLOR_NC}"
}
logWarning() {
    echo -e "${COLOR_YELLOW}$1${COLOR_NC}"
}
logError() {
    echo -e "${COLOR_RED}$1${COLOR_NC}"
}
logProgress() {
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${ts} ${COLOR_BLUE}$1${COLOR_NC}"
}

#--------------------------------------------------------------
# SCRIPTS FUNCTIONS
#--------------------------------------------------------------

# Function to check the last command error
checkError() {
    if [ $? -ne 0 ]; then
        logError "The last command failed. You can check the logs for more information."
        exit 1
    fi
}

#--------------------------------------------------------------
# KEY VAULT FUNCTIONS
#--------------------------------------------------------------

# Function to check if a Key Vault exists
checkKeyVaultExists() {
    local keyVaultName=$1

    if az keyvault show --name "${keyVaultName}" &>/dev/null; then
        return 0 # true
    else
        return 1 # false
    fi
}

# Function to get a secret from the Key Vault
getSecret() {
    local keyVaultName=$1
    local secretName=$2

    local secretValue=$(az keyvault secret show \
        --vault-name "${keyVaultName}" \
        --name "${secretName}" \
        --query value \
        --output tsv 2>/dev/null || true) # Ignore errors and return an empty string if the secret is not found

    echo "${secretValue}"
}

# Function to create or update a secret in the Key Vault
createOrUpdateSecret() {
    local keyVaultName=$1
    local secretName=$2
    local secretValue=$3

    local expiration_date=$(date -d "+2 year" +"%Y-%m-%d")

    az keyvault secret set \
        --vault-name "${keyVaultName}" \
        --name "${secretName}" \
        --value "${secretValue}" \
        --expires "${expiration_date}" \
        --output none
}

#--------------------------------------------------------------
# SSH/PASSWORD FUNCTIONS
#--------------------------------------------------------------

# Function to store the SSH keys in the Key Vault
# If the SSH keys are not found in the Key Vault, generate new keys and store them in the Key Vault
storeSSHKeysInKeyVault() {
    local keyVaultName=$1

    # Create a temporary folder
    local sshTempFolder=$(mktemp -d)
    local sshKeyFile="${sshTempFolder}/sshkey"

    if checkKeyVaultExists "${keyVaultName}"; then
        local sshPublicKey=$(getSecret "${keyVaultName}" "SSH-PUBLIC-KEY")
        local sshPrivateKey=$(getSecret "${keyVaultName}" "SSH-PRIVATE-KEY")

        if [[ -z "${sshPublicKey}" && -z "${sshPrivateKey}" ]]; then
            logInfo "SSH keys not found in the Key Vault. Generating new ones..."
            ssh-keygen -t rsa -b 4096 -f "${sshKeyFile}" -q -N ""
            createOrUpdateSecret "${keyVaultName}" "SSH-PUBLIC-KEY" "$(cat "${sshKeyFile}.pub")"
            createOrUpdateSecret "${keyVaultName}" "SSH-PRIVATE-KEY" "$(cat "${sshKeyFile}")"
        else
            logInfo "SSH keys found in the Key Vault."
        fi
    else
        logError "Key Vault not found: ${keyVaultName}. Please ensure the Key Vault name is correct and that you have the necessary permissions to access it."
        exit 1
    fi

    # Clean up the temporary folder
    rm -rf "${sshTempFolder}"
}

# Function to store the proxy password in the Key Vault
storeProxyPasswordInKeyVault() {
    local keyVaultName=$1

    if checkKeyVaultExists "${keyVaultName}"; then
        local proxyPassword=$(getSecret "${keyVaultName}" "PROXY-PASSWORD")

        if [[ -z "${proxyPassword}" ]]; then
            logInfo "Proxy password not found in the Key Vault. Generating a new one..."
            proxyPassword=$(openssl rand -base64 16)
            createOrUpdateSecret "${keyVaultName}" "PROXY-PASSWORD" "${proxyPassword}"
        else
            logInfo "Proxy password found in the Key Vault."
        fi
    else
        logError "Key Vault not found: ${keyVaultName}. Please ensure the Key Vault name is correct and that you have the necessary permissions to access it."
        exit 1
    fi
}

#--------------------------------------------------------------
# ENTRA ID FUNCTIONS
#--------------------------------------------------------------

# Function to get the principal ID of the signed-in user
getSignedInPrincipalId() {
    local signedInPrincipalType=$(az account show --query user.type --output tsv)
    local signedInPrincipalId

    case "${signedInPrincipalType}" in
    user)
        signedInPrincipalId=$(az ad signed-in-user show --query id --output tsv)
        ;;
    servicePrincipal)
        local signedInPrincipalName=$(az account show --query user.name --output tsv)
        signedInPrincipalId=$(az ad sp show --id "${signedInPrincipalName}" --query id --output tsv)
        ;;
    *)
        logError "Signed-in principal type is not supported: ${signedInPrincipalType}."
        exit 1
        ;;
    esac

    echo "${signedInPrincipalId}"
}

# Function to get the principal Type of the signed-in user
getSignedInPrincipalType() {
    local signedInPrincipalType=$(az account show --query user.type --output tsv)

    case "${signedInPrincipalType}" in
    user)
        echo "User"
        ;;
    servicePrincipal)
        echo "ServicePrincipal"
        ;;
    *)
        logError "Signed-in principal type is not supported: ${signedInPrincipalType}."
        exit 1
        ;;
    esac
}

#--------------------------------------------------------------
# DEPLOYMENT FUNCTIONS
#--------------------------------------------------------------

# Function to check the output value from the cloud deployment
checkDeploymentOutput() {
    local outputName=$1
    local outputValue="${!outputName}"

    if [[ -z "${outputValue}" || "${outputValue}" = "null" ]]; then
        logError "The value for '${outputName}' from the cloud deployment outputs is empty."
        exit 1
    fi
}

#--------------------------------------------------------------
# SCRIPTS FUNCTIONS
#--------------------------------------------------------------

# Function to add a 'child' script to the main script
addScript() {
    local file=$1
    local scriptsPath=$2
    local directory=$(dirname "$file")

    # Generate a random UUID
    local EOFSCRIPT=$(cat /proc/sys/kernel/random/uuid)

    # Create the directory if it doesn't exist
    if [[ -n "${directory}" && "${directory}" != "." ]]; then
        echo "mkdir -p ${directory}"
    fi

    # Add the script file
    echo "cat << '${EOFSCRIPT}' > ./${file}"
    cat "${scriptsPath}${file}"
    printf "\n"
    echo "${EOFSCRIPT}"
}

# Function to parse the scripts folder
parseScriptsFolder() {
    local scriptsPath=$1
    local scripts=$(find "${scriptsPath}" -type f)
    
    for script in $scripts
    do
        local file=${script#"${scriptsPath}"}
        addScript "${file}" "${scriptsPath}"
    done
}

# Function to create a base64 encoded installation script
base64script() {
    local vmAdminUserName=$1
    local shellCommandLine=$2
    local scriptsPath=$3

    # Generate a random UUID
    local EOFSCRIPT=$(cat /proc/sys/kernel/random/uuid)

    local scriptTempFolder="$(mktemp -d)"
    local scriptFileName="${scriptTempFolder}/script.sh"

cat << ${EOFSCRIPT} > "${scriptFileName}"
#!/bin/bash
$(parseScriptsFolder "${scriptsPath}")
find . -type f -name '*.sh' -exec chmod +x {} \;
sudo chown -R "${vmAdminUserName}" .
sudo -u "${vmAdminUserName}" sh << EOF
${shellCommandLine}
EOF
${EOFSCRIPT}

    # Encode the script file with gzip and base64
    # shellcheck disable=SC2002
    local BASE64_SCRIPT_VALUE=$(cat "${scriptFileName}" | gzip -9 | base64 -w 0)

    # Remove the temporary folder
    rm -rf "${scriptTempFolder}"
    echo "${BASE64_SCRIPT_VALUE}"
}
