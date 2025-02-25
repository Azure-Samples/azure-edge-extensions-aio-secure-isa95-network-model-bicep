#!/bin/bash
# shellcheck disable=SC2155

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

#--------------------------------------------------------------
# FEATURES FUNCTIONS
#--------------------------------------------------------------

# Function to check and register a feature
checkAndRegisterFeature() {
    local featureName=$1
    local featureNamespace=$2

    local featureState=$(az feature show \
        --name "${featureName}" \
        --namespace "${featureNamespace}" \
        --query "properties.state" \
        -o tsv)

    if [ "${featureState}" = "Registered" ]; then
        logInfo "${CHECK_MARK} ${featureName} feature is registered."
    else
        logWarning "${CROSS_MARK} ${featureName} feature is not registered. State: ${featureState}."
        logInfo "Registering ${featureName} feature..."

        az feature register \
            --namespace "${featureNamespace}" \
            --name "${featureName}"
    fi
}

#--------------------------------------------------------------
# RESOURCE PROVIDERS FUNCTIONS
#--------------------------------------------------------------

# Function to check and register a resource provider
checkAndRegisterProvider() {
    local providerNamespace=$1

    local providerState=$(az provider show \
        --namespace "${providerNamespace}" \
        --query "registrationState" -o tsv)

    if [ "$providerState" = "Registered" ]; then
        logInfo "${CHECK_MARK} ${providerNamespace} resource provider is already registered."
    else
        logWarning "${CROSS_MARK} ${providerNamespace} resource provider is not registered. State: ${providerState}."
        logInfo "Registering ${providerNamespace} resource provider..."

        az provider register \
            --namespace "${providerNamespace}"
    fi
}

#--------------------------------------------------------------
# REQUIREMENTS FUNCTIONS
#--------------------------------------------------------------

checkRequirements() {
    logProgress "Checking and registering required features..."

    # Requirements for using Azure Disk Encryption
    checkAndRegisterFeature "EncryptionAtHost" "Microsoft.Compute"

    logProgress "Checking and registering required resource providers..."

    # Requirements for using auto shutdown feature
    checkAndRegisterProvider "Microsoft.DevTestLab"

    # Requirements for Azure Arc-enabled Kubernetes
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/system-requirements#azure-resource-provider-requirements
    checkAndRegisterProvider "Microsoft.Kubernetes"
    checkAndRegisterProvider "Microsoft.KubernetesConfiguration"
    checkAndRegisterProvider "Microsoft.ExtendedLocation"

    # Requirements for Azure IoT Operations
    # https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-prepare-cluster?tabs=ubuntu#arc-enable-your-cluster
    checkAndRegisterProvider "Microsoft.IoTOperations"
    checkAndRegisterProvider "Microsoft.DeviceRegistry"
    checkAndRegisterProvider "Microsoft.SecretSyncController"

    # Requirements for Observability and Monitoring
    # https://learn.microsoft.com/en-us/azure/iot-operations/configure-observability-monitoring/howto-configure-observability
    checkAndRegisterProvider "Microsoft.AlertsManagement"
    checkAndRegisterProvider "Microsoft.Monitor"
    checkAndRegisterProvider "Microsoft.Dashboard"
    checkAndRegisterProvider "Microsoft.Insights"
    checkAndRegisterProvider "Microsoft.OperationalInsights"
}
