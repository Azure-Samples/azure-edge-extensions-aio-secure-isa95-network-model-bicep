targetScope = 'subscription'

// ------------------------------------------------------------
// Parameters - Core
// ------------------------------------------------------------

@description('The location targeted.')
param location string = deployment().location

@minLength(3)
@description('The prefix name (for instance aio).')
param prefix string

@minLength(3)
@description('The unique identifier.')
param id string

@minLength(3)
@description('The environment name (for instance dev).')
param environment string

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The network settings.')
param network object = {}

@description('The flag that indicates if the bastion host should be deployed.')
param deployBastionHost bool = false

// ------------------------------------------------------------
// Parameters - Signed-In User
// ------------------------------------------------------------

@description('The principal id used to deploy the infrastructure.')
param signedInPrincipalId string = ''

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
@description('The principal type used to deploy the infrastructure.')
param signedInPrincipalType string = 'ServicePrincipal'

// ------------------------------------------------------------
// Parameters - Key Vault
// ------------------------------------------------------------

@allowed(['premium', 'standard'])
@description('The key vault SKU.')
param keyVaultSku string

@allowed(['Enabled', 'Disabled'])
@description('The key vault public network access.')
param keyVaultPublicNetworkAccess string

@description('The soft-delete retention interval in days.')
param keyVaultSoftDeleteRetentionInDays int

@description('An IPv4 address or address range authorized to access the key vault.')
param keyVaultIpRule string = ''

@description('The flag to deploy the private endpoint for key vault.')
param keyVaultAddPrivateEndpoint bool

// ------------------------------------------------------------
// Parameters - Container Registry
// ------------------------------------------------------------

@allowed(['Basic', 'Standard', 'Premium'])
@description('The container registry SKU.')
param acrSku string

@allowed(['Enabled', 'Disabled'])
@description('The container registry public network access.')
param acrPublicNetworkAccess string

@description('The flag to deploy the private endpoint for container registry.')
param acrAddPrivateEndpoint bool

// ------------------------------------------------------------
// Parameters - Storage Account (Hierarchical Namespace)
// ------------------------------------------------------------

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
@description('The storage account SKU.')
param hnsStorageSku string

@allowed(['Enabled', 'Disabled'])
@description('The storage account public network access.')
param hnsStoragePublicNetworkAccess string

@description('The flag to deploy the private endpoint for storage account.')
param hnsStorageAddPrivateEndpoint bool

// ------------------------------------------------------------
// Parameters - App Configuration
// ------------------------------------------------------------

@allowed(['premium', 'standard'])
@description('The app configuration SKU.')
param appConfigurationSku string

@allowed(['Enabled', 'Disabled'])
@description('The app configuration public network access.')
param appConfigurationPublicNetworkAccess string

@description('The flag to deploy the private endpoint for app configuration.')
param appConfigurationAddPrivateEndpoint bool

// ------------------------------------------------------------
// Variables
// ------------------------------------------------------------

@description('The network resource group name.')
var networkResourceGroupName = 'rg${prefix}${id}${environment}network'

@description('The cloud resource group name.')
var cloudResourceGroupName = 'rg${prefix}${id}${environment}cloud'

// ------------------------------------------------------------
// Resources - Networking
// ------------------------------------------------------------

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: networkResourceGroupName
  location: deployment().location
  tags: {
    location: location
    prefix: prefix
    id: id
    environment: environment
  }
}

module networkModule './workloads/network/main.bicep' = {
  name: 'main-network'
  params: {
    location: location
    prefix: prefix
    id: id
    environment: environment
    network: network
    deployBastionHost: deployBastionHost
  }
  scope: networkResourceGroup
}

// ------------------------------------------------------------
// Resources - Cloud
// ------------------------------------------------------------

resource cloudResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: cloudResourceGroupName
  location: deployment().location
  tags: {
    location: location
    prefix: prefix
    id: id
    environment: environment
  }
}

module cloudModule './workloads/cloud/main.bicep' = {
  name: 'main-cloud'
  params: {
    location: location
    prefix: prefix
    id: id
    environment: environment
    network: network
    vnetName: networkModule.outputs.vnetName
    vnetResourceGroupName: networkModule.outputs.vnetResourceGroupName
    keyVaultSku: keyVaultSku
    keyVaultPublicNetworkAccess: keyVaultPublicNetworkAccess
    keyVaultSoftDeleteRetentionInDays: keyVaultSoftDeleteRetentionInDays
    keyVaultIpRule: keyVaultIpRule
    keyVaultAddPrivateEndpoint: keyVaultAddPrivateEndpoint
    acrSku: acrSku
    acrPublicNetworkAccess: acrPublicNetworkAccess
    acrAddPrivateEndpoint: acrAddPrivateEndpoint
    hnsStorageSku: hnsStorageSku
    hnsStoragePublicNetworkAccess: hnsStoragePublicNetworkAccess
    hnsStorageAddPrivateEndpoint: hnsStorageAddPrivateEndpoint
    appConfigurationSku: appConfigurationSku
    appConfigurationPublicNetworkAccess: appConfigurationPublicNetworkAccess
    appConfigurationAddPrivateEndpoint: appConfigurationAddPrivateEndpoint
    signedInPrincipalId: signedInPrincipalId
    signedInPrincipalType: signedInPrincipalType
  }
  scope: cloudResourceGroup
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output managedIdentityClusterId string = cloudModule.outputs.managedIdentityClusterId
output managedIdentityProxyId string = cloudModule.outputs.managedIdentityProxyId
output keyVaultName string = cloudModule.outputs.keyVaultName
output keyVaultResourceGroupName string = cloudModule.outputs.keyVaultResourceGroupName
output vnetName string = networkModule.outputs.vnetName
output vnetResourceGroupName string = networkModule.outputs.vnetResourceGroupName
output appConfigurationName string = cloudModule.outputs.appConfigurationName
output appConfigurationResourceGroupName string = cloudModule.outputs.appConfigurationResourceGroupName
output hnsStorageAccountId string = cloudModule.outputs.hnsStorageAccountId
output hnsStorageSchemasContainerName string = cloudModule.outputs.hnsStorageSchemasContainerName
output arcResourceGroupName string = cloudResourceGroup.name
