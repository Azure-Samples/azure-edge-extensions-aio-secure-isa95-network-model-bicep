#!/bin/bash
# shellcheck disable=SC2024

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

# Function to install k3s kubernetes distribution
installKubernetes() {
    logInfo "--------------------------------------------------"
    logInfo "K3S"
    logInfo "--------------------------------------------------"

    logProgress "Installing k3s kubernetes distribution..."
    # https://docs.k3s.io/quick-start
    # https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-prepare-cluster?tabs=ubuntu#create-a-cluster
    curl -sfL https://get.k3s.io | sh -s - --disable=traefik --write-kubeconfig-mode 644

    # Check if K3S is installed correctly
    if k3s --version &>/dev/null; then
        logInfo "k3s installed successfully."
        logInfo "$(k3s --version)"
    else
        logError "k3s installation failed. Check the logs for more information."
        exit 1
    fi

    # Configure kubectl
    logInfo "Configuring kubectl"
    mkdir -p ~/.kube
    sudo KUBECONFIG=~/.kube/config:/etc/rancher/k3s/k3s.yaml kubectl config view --flatten >~/.kube/merged
    mv ~/.kube/merged ~/.kube/config
    chmod 0600 ~/.kube/config
    export KUBECONFIG=~/.kube/config

    # Switch to k3s context
    logInfo "Switch to k3s context"
    kubectl config use-context default
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml

    # Increase the user watch/instance limits
    logInfo "Increase the user watch/instance limits"
    echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf
    echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # Increase the file descriptor limit
    logInfo "Increase the file descriptor limit"
    echo fs.file-max=100000 | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # Check if kubectl is installed correctly
    if kubectl version &>/dev/null; then
        logInfo "kubectl installed successfully."
        logInfo "$(kubectl version)"
        logInfo "$(kubectl get nodes)"
    else
        logError "kubectl installation failed. Check the logs for more information."
        exit 1
    fi

    logProgress "k3s installation completed."
}

# Function to install Helm
installHelm() {
    logInfo "--------------------------------------------------"
    logInfo "HELM"
    logInfo "--------------------------------------------------"

    logProgress "Installing Helm..."
    # https://helm.sh/docs/intro/install/
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

    # Check if Helm is installed correctly
    if helm version &>/dev/null; then
        logInfo "Helm installed successfully."
        logInfo "$(helm version)"
    else
        logError "Helm installation failed. Check the logs for more information."
        exit 1
    fi

    logProgress "Helm installation completed."
}