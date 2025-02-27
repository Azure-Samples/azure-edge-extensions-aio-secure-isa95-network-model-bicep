// ------------------------------------------------------------
// Parameters - Core
// ------------------------------------------------------------

@description('The location targeted.')
param location string = resourceGroup().location

@minLength(3)
@description('The prefix name (for instance aio).')
param prefix string

@minLength(3)
@description('The unique identifier.')
param id string

@minLength(3)
@description('The environment name (for instance dev).')
param environment string

@minLength(3)
@description('The workload or layer name (for instance cloud).')
param workload string = 'cloud'

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The network settings.')
param network object = {}

@description('The virtual network name.')
param vnetName string

@description('The virtual network resource group name.')
param vnetResourceGroupName string

// ------------------------------------------------------------
// Parameters - Signed-In User
// ------------------------------------------------------------

@description('The principal id used to deploy the infrastructure.')
param signedInPrincipalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
@description('The principal type used to deploy the infrastructure.')
param signedInPrincipalType string

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
param keyVaultIpRule string

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

var resourceSuffix = '${prefix}${id}${environment}${workload}'
var resourceTags = {
  prefix: prefix
  id: id
  environment: environment
  workload: workload
}

// ------------------------------------------------------------
// Resources - Networking (existing)
// ------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: network.subnets.cloud.name
}

// ------------------------------------------------------------
// Resources - Key Vault
// ------------------------------------------------------------

module keyVaultModule '../../modules/keyVault.bicep' = {
  name: 'add-keyvault'
  params: {
    location: location
    name: 'kv${resourceSuffix}'
    tags: resourceTags
    sku: keyVaultSku
    vnetId: vnet.id
    subnetId: subnet.id
    ipRule: keyVaultIpRule
    addPrivateEndpoint: keyVaultAddPrivateEndpoint
    publicNetworkAccess: keyVaultPublicNetworkAccess
    softDeleteRetentionInDays: keyVaultSoftDeleteRetentionInDays
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

// assign needed roles to signed-in user
module signedInUserRoleAssigments '../../modules/roles/signedInUserRoleAssignments.bicep' = {
  name: 'roles-signedin-user'
  params: {
    keyVaultName: keyVaultModule.outputs.keyVaultName
    managedGrafanaName: managedGrafana.name
    principalId: signedInPrincipalId
    principalType: signedInPrincipalType
  }
}

// ------------------------------------------------------------
// Resources - Container Registry
// ------------------------------------------------------------

module acrModule '../../modules/acr.bicep' = {
  name: 'add-acr'
  params: {
    location: location
    name: 'acr${resourceSuffix}'
    tags: resourceTags
    sku: acrSku
    vnetId: vnet.id
    subnetId: subnet.id
    addPrivateEndpoint: acrAddPrivateEndpoint
    publicNetworkAccess: acrPublicNetworkAccess
  }
}

// ------------------------------------------------------------
// Resources - Storage Account (Hierarchical Namespace)
// ------------------------------------------------------------

module hnsStorageModule '../../modules/hnsStorage.bicep' = {
  name: 'add-hnsstorage'
  params: {
    location: location
    name: 'hns${resourceSuffix}'
    tags: resourceTags
    sku: hnsStorageSku
    vnetId: vnet.id
    subnetId: subnet.id
    addPrivateEndpoint: hnsStorageAddPrivateEndpoint
    publicNetworkAccess: hnsStoragePublicNetworkAccess
  }
}

// ------------------------------------------------------------
// Resources - App Configuration
// ------------------------------------------------------------

var clusterConfigurationKeyValues = [
  {
    name: 'subscriptionId'
    value: subscription().subscriptionId
  }
  {
    name: 'hnsStorageAccountId'
    value: hnsStorageModule.outputs.hnsStorageAccountId
  }
  {
    name: 'hnsStorageSchemasContainerName'
    value: hnsStorageModule.outputs.hnsStorageSchemasContainerName
  }
  {
    name: 'keyVaultName'
    value: keyVaultModule.outputs.keyVaultName
  }
  {
    name: 'keyVaultResourceGroupName'
    value: keyVaultModule.outputs.keyVaultResourceGroupName
  }
  {
    name: 'arcResourceGroupName'
    value: resourceGroup().name
  }
  {
    name: 'monitorWorkspaceId'
    value: monitorWorkspace.id
  }
  {
    name: 'logAnalyticsWorkspaceId'
    value: logAnalyticsWorkspace.id
  }
  {
    name: 'managedGrafanaId'
    value: managedGrafana.id
  }
]

module appConfigurationModule '../../modules/appConfiguration.bicep' = {
  name: 'add-appconfiguration'
  params: {
    location: location
    name: 'appcs${resourceSuffix}'
    tags: resourceTags
    sku: appConfigurationSku
    vnetId: vnet.id
    subnetId: subnet.id
    addPrivateEndpoint: appConfigurationAddPrivateEndpoint
    publicNetworkAccess: appConfigurationPublicNetworkAccess
    keyValues: clusterConfigurationKeyValues
  }
}

// ------------------------------------------------------------
// Managed Identities
// ------------------------------------------------------------

// create managed identity for cluster
resource managedIdentityCluster 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id${resourceSuffix}-cluster'
  location: location
  tags: resourceTags
}

// assign needed roles for cluster managed identity
module managedIdentityClusterRoleAssignments '../../modules/roles/clusterRoleAssignments.bicep' = {
  name: 'role-assignments-cluster'
  params: {
    principalId: managedIdentityCluster.properties.principalId
    principalType: 'ServicePrincipal'
    keyVaultName: keyVaultModule.outputs.keyVaultName
    appConfigurationName: appConfigurationModule.outputs.appConfigurationName
    managedGrafanaName: managedGrafana.name
  }
}

// create managed identity for proxy
resource managedIdentityProxy 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id${resourceSuffix}-proxy'
  location: location
  tags: resourceTags
}

// assign needed roles for proxy managed identity
module managedIdentityProxyRoleAssignments '../../modules/roles/proxyRoleAssignments.bicep' = {
  name: 'role-assignments-proxy'
  params: {
    principalId: managedIdentityProxy.properties.principalId
    principalType: 'ServicePrincipal'
    keyVaultName: keyVaultModule.outputs.keyVaultName
    appConfigurationName: appConfigurationModule.outputs.appConfigurationName
  }
}

// ------------------------------------------------------------
// Monitoring
// ------------------------------------------------------------

// create azure monitor workspace
resource monitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: 'mws${resourceSuffix}'
  location: location
  tags: resourceTags
}

// create log analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: 'log${resourceSuffix}'
  location: location
  tags: resourceTags
}

// create azure managed grafana
resource managedGrafana 'Microsoft.Dashboard/grafana@2023-09-01' = {
  name: 'amg${resourceSuffix}'
  location: location
  tags: resourceTags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
  }
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output managedIdentityClusterId string = managedIdentityCluster.id
output managedIdentityProxyId string = managedIdentityProxy.id
output keyVaultName string = keyVaultModule.outputs.keyVaultName
output keyVaultResourceGroupName string = keyVaultModule.outputs.keyVaultResourceGroupName
output appConfigurationName string = appConfigurationModule.outputs.appConfigurationName
output appConfigurationResourceGroupName string = appConfigurationModule.outputs.appConfigurationResourceGroupName
output hnsStorageAccountId string = hnsStorageModule.outputs.hnsStorageAccountId
output hnsStorageSchemasContainerName string = hnsStorageModule.outputs.hnsStorageSchemasContainerName
