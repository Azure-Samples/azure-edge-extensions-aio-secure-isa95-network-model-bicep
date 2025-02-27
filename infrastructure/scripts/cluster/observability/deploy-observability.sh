#!/bin/bash

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

# Function to enable observability
enableObservability() {
    local clusterName="${AZURE_VIRTUAL_MACHINE_NAME}"
    local resourceGroupName=$1
    local monitorWorkspaceId=$2
    local logAnalyticsWorkspaceId=$3
    local managedGrafanaId=$4

    logInfo "--------------------------------------------------"
    logInfo "Observability"
    logInfo "--------------------------------------------------"

    logProgress "Enabling Observability..."

    # Install Azure CLI extension for Azure Managed Grafana
    logInfo "Installing Azure CLI extension for Azure Managed Grafana"
    az extension add --upgrade --name amg --allow-preview true --yes
    checkError

    # Enable metrics collection for the cluster
    logInfo "Enabling metrics collection for the cluster (1/2)"

    # Update the Azure Arc cluster to collect metrics and send them to Azure Monitor workspace
    # You also link this workspace with the Grafana instance
    az k8s-extension create \
        --name azuremonitor-metrics \
        --cluster-name "${clusterName}" \
        --resource-group "${resourceGroupName}" \
        --cluster-type connectedClusters \
        --extension-type Microsoft.AzureMonitor.Containers.Metrics \
        --configuration-settings azure-monitor-workspace-resource-id="${monitorWorkspaceId}" grafana-resource-id="${managedGrafanaId}"

    logInfo "Enabling metrics collection for the cluster (2/2)"

    # Enable Container Insights logs for logs collection
    az k8s-extension create \
        --name azuremonitor-containers \
        --cluster-name "${clusterName}" \
        --resource-group "${resourceGroupName}" \
        --cluster-type connectedClusters \
        --extension-type Microsoft.AzureMonitor.Containers \
        --configuration-settings logAnalyticsWorkspaceResourceID="${logAnalyticsWorkspaceId}"

    # Deploy OpenTelemetry Collector
    logInfo "Deploying OpenTelemetry Collector"

    kubectl get namespace azure-iot-operations || kubectl create namespace azure-iot-operations
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

    helm repo update
    helm upgrade \
        --install aio-observability open-telemetry/opentelemetry-collector \
        -f ./observability/otel-collector-values.yaml \
        --namespace azure-iot-operations

    # Configure Prometheus metrics collection
    logInfo "Configuring Prometheus metrics collection"

    kubectl apply -f ./observability/ama-metrics-prometheus-config.yaml

    logProgress "Observability enabled successfully."
}