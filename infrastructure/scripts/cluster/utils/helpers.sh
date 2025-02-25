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
# AZURE LOGIN FUNCTIONS
#--------------------------------------------------------------

# Function to login using Managed Identity
loginWithManagedIdentity() {
    logProgress "Login using Managed Identity"
    
    az login --identity --allow-no-subscriptions
    checkError

    logInfo "$(az account show)"
}

#--------------------------------------------------------------
# KEY VAULT FUNCTIONS
#--------------------------------------------------------------

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
# APP CONFIGURATION FUNCTIONS
#--------------------------------------------------------------

# Function to get a setting from the App Configuration
getSetting() {
    local appConfigurationName="${AZURE_APP_CONFIGURATION_NAME}"
    local settingName=$1

    local settingValue=$(az appconfig kv show \
        --name "${appConfigurationName}" \
        --key "${settingName}" \
        --query value \
        --output tsv)
    
    echo "${settingValue}"
}

# Function to check if a setting is defined in the App Configuration
checkSetting() {
    local settingName=$1
    local settingValue="${!settingName}"

    if [ -z "${settingValue}" ]; then
        logError "The setting ${settingName} is not defined in the App Configuration."
        exit 1
    fi
}