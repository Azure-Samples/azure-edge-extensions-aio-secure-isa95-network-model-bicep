// ------------------------------------------------------------
// Parameters - Core
// ------------------------------------------------------------

@description('The location targeted.')
param location string = resourceGroup().location

@description('The resource tags.')
param tags object = {}

// ------------------------------------------------------------
// Parameters - Key Vault
// ------------------------------------------------------------

@description('The key vault name.')
param name string

@allowed(['premium', 'standard'])
@description('The key vault SKU.')
param sku string = 'standard'

@allowed(['Enabled', 'Disabled'])
@description('The key vault public network access.')
param publicNetworkAccess string = 'Disabled'

@description('The soft-delete retention interval in days.')
param softDeleteRetentionInDays int

@description('An IPv4 address or address range authorized to access the key vault.')
param ipRule string

@description('The flag to deploy the private endpoint for key vault.')
param addPrivateEndpoint bool = true

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The virtual network resource id.')
param vnetId string

@description('The subnet resource id.')
param subnetId string

// ------------------------------------------------------------
// Parameters - Log Analytics
// ------------------------------------------------------------

@description('The log analytics workspace resource id.')
param logAnalyticsWorkspaceId string

// ------------------------------------------------------------
// Resources - Key Vault
// ------------------------------------------------------------

var keyVaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'
var keyVaultDnsGroupName = 'kvdnszonegroup'

// create key vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: sku
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: ipRule
        }
      ]
    }
  }
}

// create private endpoint for key vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (addPrivateEndpoint) {
  name: '${name}-pe'
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
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// create private dns zone for key vault
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (addPrivateEndpoint) {
  name: keyVaultPrivateDnsZoneName
  location: 'global'
  tags: tags
}

// create link between dns zone and virtual network
resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (addPrivateEndpoint) {
  parent: keyVaultPrivateDnsZone
  name: '${keyVaultPrivateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// create private dns group for key vault
resource keyVaultPrivateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (addPrivateEndpoint) {
  name: keyVaultDnsGroupName
  parent: keyVaultPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// enable diagnostics logs for key vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: '${name}-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output keyVaultName string = keyVault.name
output keyVaultResourceGroupName string = resourceGroup().name
