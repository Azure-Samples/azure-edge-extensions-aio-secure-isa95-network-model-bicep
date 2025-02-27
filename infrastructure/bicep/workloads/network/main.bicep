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
param workload string = 'network'

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The network settings.')
param network object = {}

@description('The flag that indicates if the bastion host should be deployed.')
param deployBastionHost bool = false

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

@description('The virtual network name.')
var vnetName = 'vnet${resourceSuffix}'

@description('The array of subnets.')
var subnets = [
  network.subnets.bastion
  network.subnets.cloud
  network.subnets.corp
  network.subnets.site
]

@description('The public IP address name.')
var publicIPAddressName = 'pip${resourceSuffix}'

// ------------------------------------------------------------
// Resources - Networking Security Group
// ------------------------------------------------------------

// network security group for bastion
resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-${network.subnets.bastion.name}-nsg'
  location: location
  tags: resourceTags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowLoadBalancerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudCommunicationOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// network security group for cloud
resource nsgCloud 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-${network.subnets.cloud.name}-nsg'
  location: location
  tags: resourceTags
  properties: {
    securityRules: []
  }
}

// network security group for corp
resource nsgCorp 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-${network.subnets.corp.name}-nsg'
  location: location
  tags: resourceTags
  properties: {
    securityRules: []
  }
}

// network security group for site
resource nsgSite 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: '${vnetName}-${network.subnets.site.name}-nsg'
  location: location
  tags: resourceTags
  properties: {
    securityRules: []
  }
}

// ------------------------------------------------------------
// Resources - Virtual Network and Subnets
// ------------------------------------------------------------

// create virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [network.vnet.addressPrefix]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', '${vnetName}-${subnet.name}-nsg')
          }
        }
      }
    ]
  }
  dependsOn: [
    nsgBastion
    nsgCloud
    nsgCorp
    nsgSite
  ]
}

// ------------------------------------------------------------
// Resources - Bastion Host
// ------------------------------------------------------------

// create public IP address
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (deployBastionHost) {
  name: publicIPAddressName
  location: location
  tags: resourceTags
  properties: {
    dnsSettings: {
      domainNameLabel: publicIPAddressName
    }
    publicIPAllocationMethod: 'Static'
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

// create bastion host
resource bastionHost 'Microsoft.Network/bastionHosts@2023-11-01' = if (deployBastionHost) {
  name: 'bas${resourceSuffix}'
  location: location
  tags: resourceTags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, network.subnets.bastion.name)
          }
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

// ------------------------------------------------------------
// Outputs
// ------------------------------------------------------------

output vnetName string = vnet.name
output vnetResourceGroupName string = resourceGroup().name
