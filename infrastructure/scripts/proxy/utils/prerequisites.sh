#!/bin/bash
# shellcheck disable=SC2155

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

# Suppress the "Daemons using outdated libraries" pop-up when using apt to install or update packages
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1
export NEEDRESTART_MODE=l

# Function to get lock for /var/lib/dpkg/lock-frontend
getLockFrontend() {
    sudo killall apt apt-get dpkg || true
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

# Function to install yq
installYq() {
    logInfo "Checking if yq is installed..."
    if ! yq --version &>/dev/null; then
        local version=v4.45.1
        local binary=yq_linux_amd64
        sudo wget https://github.com/mikefarah/yq/releases/download/${version}/${binary} -O /usr/bin/yq
        sudo chmod +x /usr/bin/yq
    fi

    if yq --version &>/dev/null; then
        logInfo "yq installed successfully."
        logInfo "$(yq --version)"
    else
        logError "yq installation failed. Check the logs for more information."
        exit 1
    fi
}

# Function to install squid
installSquid() {
    logInfo "Installing squid..."
    if ! squid --version &>/dev/null; then
        sudo apt-get install net-tools -y
        checkError
        sudo apt-get install apache2-utils -y
        checkError
        sudo apt-get install squid -y
        checkError
    fi

    if squid --version &>/dev/null; then
        logInfo "squid installed successfully."
        logInfo "$(squid --version)"
    else
        logError "squid installation failed. Check the logs for more information."
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
    installYq
    installAzureCli

    logProgress "Prerequisites installed successfully."
}
