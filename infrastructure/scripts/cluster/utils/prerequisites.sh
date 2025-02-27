#!/bin/bash
# shellcheck disable=SC2155

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

# Suppress the "Daemons using outdated libraries" pop-up when using apt to install or update packages
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1
export NEEDRESTART_MODE=l

# Function to get lock for /var/lib/dpkg/lock-frontend
getLockFrontend() {
    sudo flock \
        --timeout 300 /var/lib/dpkg/lock-frontend \
        --command 'echo -e "Acquired lock /var/lib/dpkg/lock-frontend"'
}

# Function to upgrade packages
upgradePackages() {
    logInfo "Upgrading packages..."
    sudo apt-get update
    sudo apt-get upgrade -y
}

# Function to install jq
installJq() {
    logInfo "Checking if jq is installed..."
    if ! jq --version &>/dev/null; then
        sudo apt-get install jq -y
    fi

    if jq --version &>/dev/null; then
        logInfo "jq installed successfully."
        logInfo "$(jq --version)"
    else
        logError "jq installation failed. Check the logs for more information."
        exit 1
    fi
}

# Function to install Azure CLI
installAzureCli() {
    logInfo "Checking if Azure CLI is installed..."
    if ! az --version &>/dev/null; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi

    if az --version &>/dev/null; then
        logInfo "Azure CLI installed successfully."
        logInfo "$(az --version)"
    else
        logError "Azure CLI installation failed. Check the logs for more information."
        exit 1
    fi
}

# Function to install prerequisites
installPreRequisites() {
    logInfo "--------------------------------------------------"
    logInfo "PRE-REQUISITES"
    logInfo "--------------------------------------------------"

    logProgress "Installing prerequisites..."

    getLockFrontend
    upgradePackages
    installJq
    installAzureCli

    logProgress "Prerequisites installed successfully."
}
