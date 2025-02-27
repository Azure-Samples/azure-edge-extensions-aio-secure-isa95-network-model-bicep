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

@description('The container registry name.')
param name string

@allowed(['Basic', 'Standard', 'Premium'])
@description('The container registry SKU.')
param sku string = 'Premium'

@allowed(['Enabled', 'Disabled'])
@description('The container registry public network access.')
param publicNetworkAccess string = 'Disabled'

@description('The flag to deploy the private endpoint for container registry.')
param addPrivateEndpoint bool = true

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The virtual network resource id.')
param vnetId string

@description('The subnet resource id.')
param subnetId string

// ------------------------------------------------------------
// Resources - Container Registry
// ------------------------------------------------------------

var acrPrivateDnsZoneName = 'privatelink${az.environment().suffixes.acrLoginServer}'
var acrDnsGroupName = 'acrdnszonegroup'

// create azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: publicNetworkAccess
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
    }
  }
  //checkov:skip=CKV_AZURE_163:Enable vulnerability scanning for container images. 
}

// create private endpoint for container registry
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (addPrivateEndpoint) {
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
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// create private dns zone for container registry
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (addPrivateEndpoint) {
  name: acrPrivateDnsZoneName
  location: 'global'
  tags: tags
}

// create link between dns zone and virtual network
resource acrPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (addPrivateEndpoint) {
  parent: acrPrivateDnsZone
  name: '${acrPrivateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// create private dns group for container registry
resource acrPrivateEndpointDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = if (addPrivateEndpoint) {
  name: acrDnsGroupName
  parent: acrPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output acrName string = acr.name
output acrResourceGroupName string = resourceGroup().name
