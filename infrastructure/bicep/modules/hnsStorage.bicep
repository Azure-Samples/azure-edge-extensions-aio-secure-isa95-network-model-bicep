// ------------------------------------------------------------
// Parameters - Core
// ------------------------------------------------------------

@description('The location targeted.')
param location string = resourceGroup().location

@description('The resource tags.')
param tags object = {}

// ------------------------------------------------------------
// Parameters - Storage Account
// ------------------------------------------------------------

@description('The storage account name.')
param name string

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
param sku string = 'Standard_LRS'

@allowed(['Enabled', 'Disabled'])
@description('The storage account public network access.')
param publicNetworkAccess string

@description('The flag to deploy the private endpoint for storage account.')
param addPrivateEndpoint bool

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The virtual network resource id.')
param vnetId string

@description('The subnet resource id.')
param subnetId string

// ------------------------------------------------------------
// Resources - Storage Account
// ------------------------------------------------------------

var storagePrivateDnsZones = [
  {
    name: 'privatelink.blob.${az.environment().suffixes.storage}'
    groupId: 'blob'
    groupName: 'blobdnszonegroup'
  }
  {
    name: 'privatelink.dfs.${az.environment().suffixes.storage}'
    groupId: 'dfs'
    groupName: 'dfsdnszonegroup'
  }
]

// create storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    isHnsEnabled: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    
  }
  //checkov:skip=CKV_AZURE_206:Ensure that Storage Accounts use replication
}

// create private endpoint for storage account
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = [
  for privateDnsZone in storagePrivateDnsZones: if (addPrivateEndpoint) {
    name: '${privateDnsZone.name}-pe'
    location: location
    tags: tags
    properties: {
      subnet: {
        id: subnetId
      }
      privateLinkServiceConnections: [
        {
          name: '${name}-plsc'
          properties: {
            privateLinkServiceId: storageAccount.id
            groupIds: [
              privateDnsZone.groupId
            ]
          }
        }
      ]
    }
  }
]

// create private dns zone for storage account
resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [
  for privateDnsZone in storagePrivateDnsZones: if (addPrivateEndpoint) {
    name: privateDnsZone.name
    location: 'global'
    tags: tags
  }
]

// create link between dns zone and virtual network
resource storagePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [
  for (privateDnsZone, index) in storagePrivateDnsZones: if (addPrivateEndpoint) {
    parent: storagePrivateDnsZone[index]
    name: '${privateDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnetId
      }
    }
  }
]

// create private dns group for storage account
resource storagePrivateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = [
  for (privateDnsZone, index) in storagePrivateDnsZones: if (addPrivateEndpoint) {
    name: privateDnsZone.groupName
    parent: storagePrivateEndpoint[index]
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'default'
          properties: {
            privateDnsZoneId: storagePrivateDnsZone[index].id
          }
        }
      ]
    }
  }
]

// ------------------------------------------------------------
// Containers
// ------------------------------------------------------------

var schemasContainerName = 'schemas'

// create storage container (schemas)
resource schemasStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${name}/default/${schemasContainerName}'
  properties: {
    publicAccess: 'None'
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
  }
  dependsOn: [
    storageAccount
  ]
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output hnsStorageName string = storageAccount.name
output hnsStorageResourceGroupName string = resourceGroup().name
output hnsStorageAccountId string = storageAccount.id
output hnsStorageSchemasContainerName string = schemasContainerName
