#!/bin/bash
# shellcheck disable=SC2155

# THIS SCRIPT IS INTENDED TO BE SOURCED BY THE MAIN SCRIPT

# Function to enable Azure Arc for Kubernetes on a specified cluster.
arcEnablingKubernetes() {
    local clusterName="${AZURE_VIRTUAL_MACHINE_NAME}"
    local resourceGroupName=$1
    local subscriptionId=$2
    local customLocationsRpObjectId=$3

    logInfo "--------------------------------------------------"
    logInfo "ARC"
    logInfo "--------------------------------------------------"

    logProgress "Enabling Azure Arc for Kubernetes..."

    # Arc-enable Kubernetes cluster
    # https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-prepare-cluster?tabs=ubuntu#arc-enable-your-cluster

    # Install the latest version of connectedk8s Azure CLI extension:
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/system-requirements#management-tool-requirements
    logInfo "Installing connectedk8s Azure CLI extension..."
    az extension add --upgrade --name connectedk8s --allow-preview true --yes
    checkError

    # Connect the Kubernetes cluster to Azure Arc
    logInfo "Checking if cluster ${clusterName} is already Arc connected..."
    local provisioningState=$(
        az connectedk8s show \
            --name "${clusterName}" \
            --resource-group "${resourceGroupName}" \
            --subscription "${subscriptionId}" \
            --query provisioningState -o tsv
    ) || true

    if [ "${provisioningState}" == "Succeeded" ]; then
        logInfo "Cluster ${clusterName} is already Arc connected."
    else
        logInfo "Cluster ${clusterName} is not Arc connected. Enabling..."
        if [ "${HTTP_PROXY:-default}" != "default" ] && [ "${HTTPS_PROXY:-default}" != "default" ] && [ "${NO_PROXY:-default}" != "default" ]; then
            logInfo "Using proxy settings..."
            az connectedk8s connect \
                --name "${clusterName}" \
                --resource-group "${resourceGroupName}" \
                --subscription "${subscriptionId}" \
                --enable-oidc-issuer \
                --enable-workload-identity \
                --distribution k3s \
                --proxy-http "${HTTP_PROXY}" \
                --proxy-https "${HTTPS_PROXY}" \
                --proxy-skip-range "${NO_PROXY}"
            checkError
        else
            az connectedk8s connect \
                --name "${clusterName}" \
                --resource-group "${resourceGroupName}" \
                --subscription "${subscriptionId}" \
                --enable-oidc-issuer \
                --enable-workload-identity \
                --distribution k3s
            checkError
        fi
    fi

    # Get the OIDC issuer URL
    logInfo "Getting the OIDC issuer URL..."
    local oidcIssuerUrl=$(
        az connectedk8s show \
            --name "${clusterName}" \
            --resource-group "${resourceGroupName}" \
            --subscription "${subscriptionId}" \
            --query oidcIssuerProfile.issuerUrl \
            --output tsv
    )
    if [ -z "${oidcIssuerUrl}" ]; then
        logError "OIDC issuer URL not found. Check the logs for more information."
        exit 1
    fi

    # Configure the kube-apiserver to use the OIDC issuer URL
    logInfo "Configuring kube-apiserver to use the OIDC issuer URL..."
    cat <<YAML | sudo tee "/etc/rancher/k3s/config.yaml"
kube-apiserver-arg:
 - service-account-issuer=${oidcIssuerUrl}
 - service-account-max-token-expiration=24h
YAML

    # Enable custom locations feature
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-custom-locations
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/custom-locations#enable-custom-locations-on-your-cluster
    az connectedk8s enable-features \
        --name "${clusterName}" \
        --resource-group "${resourceGroupName}" \
        --custom-locations-oid "${customLocationsRpObjectId}" \
        --features cluster-connect custom-locations

    # Restart the k3s service
    logInfo "Restarting k3s service..."
    sudo systemctl restart k3s

    # Display the deployments and pods in the azure-arc namespace
    logInfo "$(kubectl get deployments,pods --namespace azure-arc)"
    # List connected clusters and reported agent version
    logInfo "$(az connectedk8s list --query '[].{name:name,rg:resourceGroup,id:id,version:agentVersion}')"

    logProgress "Kubernetes on Azure Arc enabled successfully."
}

# Function to configure Azure Arc authentication.
arcAuthentication() {
    local clusterName="${AZURE_VIRTUAL_MACHINE_NAME}"
    local keyVaultName=$1

    logInfo "--------------------------------------------------"
    logInfo "ARC - Authentication"
    logInfo "--------------------------------------------------"

    logProgress "Configuring Azure Arc authentication..."
    # Service account token authentication option
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/cluster-connect?tabs=azure-cli%2Cagent-version#service-account-token-authentication-option

    local serviceAccountName="arc-user"
    local clusterRoleBindingName="arc-user-binding"

    # Creates the service account in the default namespace
    logInfo "Creating service account..."
    if kubectl get serviceaccount "${serviceAccountName}" --namespace default &>/dev/null; then
        logInfo "Service account ${serviceAccountName} already exists."
    else
        kubectl create serviceaccount "${serviceAccountName}" --namespace default
        checkError
    fi

    # Grant this service account the appropriate permissions on the cluster
    logInfo "Granting permissions..."
    if kubectl get clusterrolebinding "${clusterRoleBindingName}" &>/dev/null; then
        logInfo "Cluster role binding ${clusterRoleBindingName} already exists."
    else
        kubectl create clusterrolebinding ${clusterRoleBindingName} \
            --clusterrole cluster-admin \
            --serviceaccount "default:${serviceAccountName}"
        checkError
    fi

    # Create a service account token
    logInfo "Creating service account token..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
    name: arc-user-secret
    annotations:
        kubernetes.io/service-account.name: ${serviceAccountName}
type: kubernetes.io/service-account-token
EOF
    checkError

    # Get the token
    local token=$(kubectl get secret arc-user-secret -o jsonpath='{$.data.token}' | base64 -d | sed 's/$/\n/g')

    if [ -z "${token}" ]; then
        logError "Token not found. Check the logs for more information."
        exit 1
    else
        clusterNameUpper=$(echo "${clusterName}" | tr '[:lower:]' '[:upper:]')
        createOrUpdateSecret "${keyVaultName}" "${clusterNameUpper}-CLUSTER-CONNECT-TOKEN" "${token}"
    fi
}

# Function to add the Flux extension to the Azure Arc enabled Kubernetes cluster.
arcFluxExtension() {
    local clusterName="${AZURE_VIRTUAL_MACHINE_NAME}"
    local resourceGroupName=$1

    logInfo "--------------------------------------------------"
    logInfo "ARC - FLUX"
    logInfo "--------------------------------------------------"

    # Install the latest version of k8s-extension and k8s-configuration extensions
    logInfo "Installing k8s-extension and k8s-configuration extensions"
    az extension add --upgrade --name k8s-extension --allow-preview true --yes
    checkError
    az extension add --upgrade --name k8s-configuration --allow-preview true --yes
    checkError

    # Create flux extension instance
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/extensions#create-extension-instance
    logInfo "Creating flux extension instance"
    az k8s-extension create \
        --name flux \
        --extension-type microsoft.flux \
        --cluster-name "${clusterName}" \
        --scope cluster \
        --resource-group "${resourceGroupName}" \
        --cluster-type connectedClusters
    checkError

    # Optout of multi-tenancy
    # https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2#opt-out-of-multi-tenancy
    logInfo "Opting out of multi-tenancy"
    az k8s-extension update \
        --name flux \
        --configuration-settings multiTenancy.enforce=false \
        --cluster-name "${clusterName}" \
        --resource-group "${resourceGroupName}" \
        --cluster-type connectedClusters \
        --yes
    checkError
}
