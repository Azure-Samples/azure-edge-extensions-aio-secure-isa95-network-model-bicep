# How to deploy Infrastructure

## Settings

The [environments](../infrastructure/bicep/environments/) folder contains configuration settings necessary for deploying the solution. These settings are stored in `.json` files and adhere to the Resource Manager parameter file schema. For more detailed information, please refer to the [documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files).

At this stage of the project, the `environments` folder contains settings for `development`. In the future, a similar structure can be replicated for other environments as needed.

### Folder Structure

The `environments` directory is organized to support the configuration of different workloads within the `development` environment. The structure is as follows:

```txt
environments/
└─ development/
    ├─ clusters.json
    ├─ common.json
    ├─ fundamentals.json
    ├─ network.json
    └─ proxies.json
```

Each `.json` file corresponds to a set of parameters used during the deployment. If you want to update the SKU of a service or change the image reference used by the VMs, you will likely find the appropriate value in these files. The `common.json` file contains shared settings applicable across all layers, while the `network.json` file provides details related to the networking configuration.

## Requirements

If you add your own environment, you can copy and paste an existing configuration and update the `common.json` file as described below. While other files should remain unchanged, it is advisable to review their settings, such as SKUs and VM sizes, to ensure they meet your requirements.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "__LOCATION__"
        },
        "prefix": {
            "value": "__PREFIX__"
        },
        "uid": {
            "value": "__UID__"
        },
        "environment": {
            "value": "__ENVIRONMENT__"
        }
    }
}
```

Example:

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "value": "eastus2"
        },
        "prefix": {
            "value": "aio"
        },
        "uid": {
            "value": "101"
        },
        "environment": {
            "value": "dev"
        }
    }
}
```

- `location`: The Azure location targeted
- `prefix`: The prefix name (for instance aio)
- `uid`: The unique identifier
- `environment`: The environment name (for instance dev)

These settings are used to create resources. The naming convention for resources is as follows: `resource[prefix][uid][environment]workload`. For example, a resource might be named `kvaio101devcorp`.

## Usage

``` shell
Usage: ./deploy-infra-main.sh [-e environment] -o custom_locations_rp_object_id [--install-requirements] [--install-proxy] [--install-iot-operations] [--verbose]
```

0. Sign into Azure using Azure CLI

    ``` bash
    cd ./infrastructure/scripts/azure
    az login
    ```

1. Execute the following command to verify if all requirements are met.

    ``` bash
    cd ./infrastructure/scripts/azure
    ./deploy-infra-main.sh -e development --install-requirements
    ```

    This script will ensure that the following resources are created and registered accordingly.

    - Features
        - EncryptionAtHost
    - Providers
        - Microsoft.DevTestLab
        - Microsoft.Kubernetes
        - Microsoft.KubernetesConfiguration
        - Microsoft.ExtendedLocation
        - Microsoft.IoTOperations
        - Microsoft.DeviceRegistry
        - Microsoft.SecretSyncController
        - Microsoft.AlertsManagement
        - Microsoft.Monitor
        - Microsoft.Dashboard
        - Microsoft.Insights
        - Microsoft.OperationalInsights

    Encryption at host is a Virtual Machine option that enhances Azure Disk Storage Server-Side Encryption to ensure that all temp disks and disk caches are encrypted at rest and flow encrypted to the Storage clusters. For full details, see [Encryption at host - End-to-end encryption for your VM data](https://learn.microsoft.com/en-us/azure/virtual-machines/disk-encryption).

    All providers listed are required for [Arc-enabling Kubernetes cluster](https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-prepare-cluster?tabs=ubuntu#arc-enable-your-cluster) and installing Azure IoT Operations.

    >This step only needs to be run once per subscription. To register resource providers, you need permission to do the /register/action operation, which is included in subscription `Contributor` and `Owner` roles.

2. Prior to proceeding to next step, please execute the following command manually:

    ```bash
    export CUSTOM_LOCATIONS_RP_OBJECT_ID=$(az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv)
    ```

3. Execute the following command to deploy the infrastructure:

    This command deploys the necessary infrastructure for networking, fundamental services (such as app configuration and key vault), cluster virtual machines with Kubernetes (k3s distribution), and integrates the clusters into Azure Arc. Azure IoT Operations is not installed at this stage.

    ```shell
    ./deploy-infra-main.sh -e development -o $CUSTOM_LOCATIONS_RP_OBJECT_ID
    ```

    If you want to deploy the infrastructure with a proxy between the site at level 3 (Site) and level 4 (Corp), and a proxy between level 4 (Corp) and level 5 (Cloud), run the command below instead. The proxy solution used in this demo relies on [Squid](https://www.squid-cache.org/).

    ```shell
    ./deploy-infra-main.sh -e development -o $CUSTOM_LOCATIONS_RP_OBJECT_ID --install-proxy
    ```

4. Finally, once the clusters are installed and enrolled into Azure Arc, you can deploy Azure IoT Operations:

    ```shell
    ./deploy-infra-main.sh -e development --install-iot-operations
    ```

### Options

The `--verbose` option can be enabled to display all bash and `az` commands. This is intended for use in debugging scenarios.
