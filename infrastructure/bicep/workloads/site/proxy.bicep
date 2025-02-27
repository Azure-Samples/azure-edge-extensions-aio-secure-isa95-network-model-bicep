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
param workload string = 'site'

// ------------------------------------------------------------
// Parameters - Virtual Machine (Proxy)
// ------------------------------------------------------------

@description('Specifies admin username.')
param proxyAdminUserName string

@description('Specifies admin public key.')
param proxyAdminPublicKey string

@description('Specifies image reference.')
param proxyImageReference object

@description('Specifies the size.')
param proxySize string

@description('Specifies managed identity resource ID.')
param proxyManagedIdentityId string

@allowed([
  'Enabled'
  'Disabled'
])
@description('Specifies the status of the auto shutdown.')
param proxyAutoShutdownStatus string

@description('Specifies the time (24h HHmm format) of the auto shutdown.')
@minLength(4)
@maxLength(4)
param proxyAutoShutdownTime string

@description('Specifies the time zone of the auto shutdown.')
param proxyAutoShutdownTimeZoneId string

@description('Specifies the base64 encoded script to run on the Virtual Machine.')
param proxyBase64Script string

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

resource corpSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: network.subnets.corp.name
}

resource siteSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: network.subnets.site.name
}

// ------------------------------------------------------------
// Resource - Virtual Machine (Proxy)
// ------------------------------------------------------------

// create proxy virtual machine
module vmProxy '../../modules/virtualMachineProxy.bicep' = {
  name: 'add-vmproxy'
  params: {
    location: location
    name: 'proxy${resourceSuffix}'
    size: proxySize
    imageReference: proxyImageReference
    adminUserName: proxyAdminUserName
    adminPublicKey: proxyAdminPublicKey
    managedIdentityId: proxyManagedIdentityId
    frontSubnetId: corpSubnet.id
    backSubnetId: siteSubnet.id
    frontPrivateIPAddress: network.subnets.site.proxy.frontPrivateIPAddress
    backPrivateIPAddress: network.subnets.site.proxy.backPrivateIPAddress
    autoShutdownStatus: proxyAutoShutdownStatus
    autoShutdownTime: proxyAutoShutdownTime
    autoShutdownTimeZoneId: proxyAutoShutdownTimeZoneId
    base64script: proxyBase64Script
    tags: resourceTags
  }
}
