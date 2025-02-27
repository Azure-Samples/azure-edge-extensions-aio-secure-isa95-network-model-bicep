#!/bin/bash
# shellcheck disable=SC2155

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

# Function to install the Azure IoT Operations Azure CLI extension
installExtension() {
    logProgress "Installing Azure IoT Operations Azure CLI extension"

    az extension add --upgrade --name azure-iot-ops --allow-preview true --yes
    checkError
}

# Function to install the Azure IoT Operations
installIoTOperations() {
    local clusterName=$1
    local resourceGroupName=$2
    local storageAccountId=$3
    local storageContainerName=$4

    local schemaRegistryName="${clusterName}-sr"
    local schemaRegistryNamespace="${clusterName}-srns"

    logProgress "Installing Schema Registry..."

    if ! az iot ops schema registry show --name "${schemaRegistryName}" --resource-group "${resourceGroupName}" &>/dev/null; then
        az iot ops schema registry create \
            --name "${schemaRegistryName}" \
            --registry-namespace "${schemaRegistryNamespace}" \
            --resource-group "${resourceGroupName}" \
            --sa-resource-id "${storageAccountId}" \
            --sa-container "${storageContainerName}"
        checkError
    else
        logInfo "Schema registry ${schemaRegistryName} already exists in namespace ${schemaRegistryNamespace}"
    fi

    local schemaRegistryResourceId=$(az iot ops schema registry show \
        --name "${schemaRegistryName}" \
        --resource-group "${resourceGroupName}" \
        --query id \
        --output tsv)

    # Prepare the cluster for Azure IoT Operations
    logProgress "Preparing the cluster for Azure IoT Operations..."
    az iot ops init \
        --cluster "${clusterName}" \
        --resource-group "${resourceGroupName}"
    checkError

    # Deploy Azure IoT Operations
    logProgress "Deploying Azure IoT Operations..."
    local iotOperationsName="${clusterName}-iot"
    local iotOperationsCustomLocationName="${clusterName}-cl"

     if ! az iot ops show --name "${iotOperationsName}" --resource-group "${resourceGroupName}" &>/dev/null; then
        az iot ops create \
            --name "${iotOperationsName}" \
            --cluster "${clusterName}" \
            --resource-group "${resourceGroupName}" \
            --custom-location "${iotOperationsCustomLocationName}" \
            --sr-resource-id "${schemaRegistryResourceId}" \
            --broker-listener-type "LoadBalancer" \
            --enable-rsync false \
            --kubernetes-distro K3s \
            --ops-config observability.metrics.openTelemetryCollectorAddress=aio-otel-collector.azure-iot-operations.svc.cluster.local:4317 \
            --ops-config observability.metrics.exportInternalSeconds=60s
        checkError
    else
        logInfo "IoT Operations instance ${iotOperationsName} already exists"
    fi
}

installIoTOperationsOnAllClusters() {
    
    # Install the Azure IoT Operations Azure CLI extension
    installExtension

    local fundamentalsDeploymentName="fundamentals"

    # Get the outputs of the deployment
    logInfo "Getting the outputs of the deployment..."
    local fundamentalsDeploymentOutputs=$(az deployment sub show \
        --name "${fundamentalsDeploymentName}" \
        --query properties.outputs)

    local hnsStorageAccountId=$(echo "${fundamentalsDeploymentOutputs}" | jq -r .hnsStorageAccountId.value)
    checkDeploymentOutput hnsStorageAccountId
    local hnstorageSchemasContainerName=$(echo "${fundamentalsDeploymentOutputs}" | jq -r .hnsStorageSchemasContainerName.value)
    checkDeploymentOutput hnstorageSchemasContainerName
    local arcResourceGroupName=$(echo "${fundamentalsDeploymentOutputs}" | jq -r .arcResourceGroupName.value)
    checkDeploymentOutput arcResourceGroupName

    #--------------------------------------------------------------
    # CORP INFRASTRUCTURE
    #--------------------------------------------------------------
    logInfo "--------------------------------------------------"
    logInfo "CORP INFRASTRUCTURE"
    logInfo "--------------------------------------------------"

    # Check if the resource group already exists, exit if it does not
    logInfo "Checking if the resource group exists..."
    local corpResourceGroupName="rg${PREFIX}${ID}${ENVIRONMENT}cloud"
    local corpResourceGroupNameExists=$(az group exists --name "${corpResourceGroupName}")
    if [ "${corpResourceGroupNameExists}" == "false" ]; then
        logError "Resource group '${corpResourceGroupName}' does not exist."
        exit 1
    fi

    local corpClusterName="cluster${PREFIX}${ID}${ENVIRONMENT}corp"
    installIoTOperations \
        "${corpClusterName}" \
        "${arcResourceGroupName}" \
        "${hnsStorageAccountId}" \
        "${hnstorageSchemasContainerName}"

    #--------------------------------------------------------------
    # SITE INFRASTRUCTURE
    #--------------------------------------------------------------
    logInfo "--------------------------------------------------"
    logInfo "SITE INFRASTRUCTURE"
    logInfo "--------------------------------------------------"

    # Check if the resource group already exists, exit if it does not
    logInfo "Checking if the resource group exists..."
    local siteResourceGroupName="rg${PREFIX}${ID}${ENVIRONMENT}site"
    local siteResourceGroupNameExists=$(az group exists --name "${siteResourceGroupName}")
    if [ "${siteResourceGroupNameExists}" == "false" ]; then
        logError "Resource group '${siteResourceGroupName}' does not exist."
        exit 1
    fi

    local siteClusterName="cluster${PREFIX}${ID}${ENVIRONMENT}site"
    installIoTOperations \
        "${siteClusterName}" \
        "${arcResourceGroupName}" \
        "${hnsStorageAccountId}" \
        "${hnstorageSchemasContainerName}"
}