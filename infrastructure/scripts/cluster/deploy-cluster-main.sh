#!/bin/bash
# shellcheck disable=SC1091
set -ue

# Import utils functions
source ./utils/helpers.sh
source ./utils/prerequisites.sh
source ./arc/deploy-k3s.sh
source ./arc/deploy-arc.sh
source ./observability/deploy-observability.sh

#--------------------------------------------------------------
# PARSE COMMAND-LINE ARGUMENTS
#--------------------------------------------------------------

# Initialize variables (inputs)
AZURE_APP_CONFIGURATION_NAME=""
AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID=""

# Initialize variables (app configuration settings)
AZURE_SUBSCRIPTION_ID=""
AZURE_KEYVAULT_NAME=""
AZURE_ARC_RESOURCE_GROUP_NAME=""

# Initialize variables (others)
AZURE_VIRTUAL_MACHINE_NAME=$(hostname)

# Function to display usage information
usage() {
    echo "Usage: $0 -a app_configuration_name -o custom_locations_rp_object_id [--verbose]"
    exit 1
}

# Function to parse command-line arguments
parseArguments() {
    while getopts ":-:a:o:" opt; do
        case ${opt} in
        -) case "${OPTARG}" in
            verbose) set -x ;;
            *) usage ;;
            esac ;;
        a) export AZURE_APP_CONFIGURATION_NAME=$OPTARG ;;
        o) export AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID=$OPTARG ;;
        \?) usage ;;
        esac
    done

    # Validate required arguments
    if [ -z "${AZURE_APP_CONFIGURATION_NAME}" ] || [ -z "${AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID}" ]; then
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
AZURE_KEYVAULT_NAME=$(getSetting keyVaultName)
checkSetting AZURE_KEYVAULT_NAME
AZURE_ARC_RESOURCE_GROUP_NAME=$(getSetting arcResourceGroupName)
checkSetting AZURE_ARC_RESOURCE_GROUP_NAME
AZURE_MONITOR_WORKSPACE_ID=$(getSetting monitorWorkspaceId)
checkSetting AZURE_MONITOR_WORKSPACE_ID
AZURE_LOG_ANALYTICS_WORKSPACE_ID=$(getSetting logAnalyticsWorkspaceId)
checkSetting AZURE_LOG_ANALYTICS_WORKSPACE_ID
AZURE_MANAGED_GRAFANA_ID=$(getSetting managedGrafanaId)
checkSetting AZURE_MANAGED_GRAFANA_ID

#--------------------------------------------------------------
# KUBERNETES
#--------------------------------------------------------------

installKubernetes
installHelm

#--------------------------------------------------------------
# ARC
#--------------------------------------------------------------

arcEnablingKubernetes "${AZURE_ARC_RESOURCE_GROUP_NAME}" "${AZURE_SUBSCRIPTION_ID}" "${AZURE_CUSTOM_LOCATIONS_RP_OBJECT_ID}"
arcAuthentication "${AZURE_KEYVAULT_NAME}"
arcFluxExtension "${AZURE_ARC_RESOURCE_GROUP_NAME}"

#--------------------------------------------------------------
# OBSERVABILITY
#--------------------------------------------------------------

enableObservability "${AZURE_ARC_RESOURCE_GROUP_NAME}" "${AZURE_MONITOR_WORKSPACE_ID}" "${AZURE_LOG_ANALYTICS_WORKSPACE_ID}" "${AZURE_MANAGED_GRAFANA_ID}"