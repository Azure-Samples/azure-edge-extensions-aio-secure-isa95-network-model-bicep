// ------------------------------------------------------------
// Parameters - Core
// ------------------------------------------------------------

@description('The location targeted.')
param location string = resourceGroup().location

@description('The resource tags.')
param tags object = {}

// ------------------------------------------------------------
// Parameters - App Configuration
// ------------------------------------------------------------

@description('The app configuration name.')
param name string

@allowed(['premium', 'standard'])
@description('The app configuration SKU.')
param sku string = 'standard'

@allowed(['Enabled', 'Disabled'])
@description('The app configuration public network access.')
param publicNetworkAccess string = 'Disabled'

@description('The flag to deploy the private endpoint for app configuration.')
param addPrivateEndpoint bool = true

@description('The key values.')
param keyValues array = []

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The virtual network resource id.')
param vnetId string

@description('The subnet resource id.')
param subnetId string

// ------------------------------------------------------------
// Resources - App Configuration
// ------------------------------------------------------------

var appConfigurationPrivateDnsZoneName = 'privatelink.azconfig.io'
var appConfigurationDnsGroupName = 'azconfigdnszonegroup'

// create app configuration store
resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
}

// create key values
resource appConfigurationKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [
  for keyValue in keyValues: {
    parent: appConfiguration
    name: keyValue.name
    properties: {
      value: keyValue.value
      tags: tags
    }
  }
]

// create private endpoint for app configuration
resource appConfigurationPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if(addPrivateEndpoint) {
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
          privateLinkServiceId: appConfiguration.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}

// create private dns zone for app configuration
resource appConfigurationPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (addPrivateEndpoint) {
  name: appConfigurationPrivateDnsZoneName
  location: 'global'
  tags: tags
}

// create link between dns zone and virtual network
resource appConfigurationPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (addPrivateEndpoint) {
  parent: appConfigurationPrivateDnsZone
  name: '${appConfigurationPrivateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// create private dns group for app configuration
resource appConfigurationPrivateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (addPrivateEndpoint) {
  name: appConfigurationDnsGroupName
  parent: appConfigurationPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: appConfigurationPrivateDnsZone.id
        }
      }
    ]
  }
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output appConfigurationName string = appConfiguration.name
output appConfigurationResourceGroupName string = resourceGroup().name

