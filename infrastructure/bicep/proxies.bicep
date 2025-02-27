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

@description('The virtual network name.')
param vnetName string

@description('The virtual network resource group name.')
param vnetResourceGroupName string

// ------------------------------------------------------------
// Parameters - Virtual Machine (Cluster)
// ------------------------------------------------------------

@description('Specifies admin username.')
param proxyAdminUserName string

@secure()
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

@description('Specifies the base64 encoded script to run on the Virtual Machine (Corp).')
param proxyCorpBase64Script string

@description('Specifies the base64 encoded script to run on the Virtual Machine (Site).')
param proxySiteBase64Script string

// ------------------------------------------------------------
// Variables
// ------------------------------------------------------------

@description('The corp resource group name.')
var corpResourceGroupName = 'rg${prefix}${id}${environment}corp'

@description('The site resource group name.')
var siteResourceGroupName = 'rg${prefix}${id}${environment}site'

// ------------------------------------------------------------
// Resources - Corp
// ------------------------------------------------------------

resource corpResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: corpResourceGroupName
  location: deployment().location
  tags: {
    location: location
    prefix: prefix
    id: id
    environment: environment
  }
}

module corpProxyModule './workloads/corp/proxy.bicep' = {
  name: 'corp-proxy'
  params: {
    location: location
    prefix: prefix
    id: id
    environment: environment
    network: network
    vnetName: vnetName
    vnetResourceGroupName: vnetResourceGroupName
    proxyAdminUserName: proxyAdminUserName
    proxyAdminPublicKey: proxyAdminPublicKey
    proxyImageReference: proxyImageReference
    proxySize: proxySize
    proxyManagedIdentityId: proxyManagedIdentityId
    proxyAutoShutdownStatus: proxyAutoShutdownStatus
    proxyAutoShutdownTime: proxyAutoShutdownTime
    proxyAutoShutdownTimeZoneId: proxyAutoShutdownTimeZoneId
    proxyBase64Script: proxyCorpBase64Script
  }
  scope: corpResourceGroup
}

// ------------------------------------------------------------
// Resources - Site
// ------------------------------------------------------------

resource siteResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: siteResourceGroupName
  location: deployment().location
  tags: {
    location: location
    prefix: prefix
    id: id
    environment: environment
  }
}

module siteProxyModule './workloads/site/proxy.bicep' = {
  name: 'site-proxy'
  params: {
    location: location
    prefix: prefix
    id: id
    environment: environment
    network: network
    vnetName: vnetName
    vnetResourceGroupName: vnetResourceGroupName
    proxyAdminUserName: proxyAdminUserName
    proxyAdminPublicKey: proxyAdminPublicKey
    proxyImageReference: proxyImageReference
    proxySize: proxySize
    proxyManagedIdentityId: proxyManagedIdentityId
    proxyAutoShutdownStatus: proxyAutoShutdownStatus
    proxyAutoShutdownTime: proxyAutoShutdownTime
    proxyAutoShutdownTimeZoneId: proxyAutoShutdownTimeZoneId
    proxyBase64Script: proxySiteBase64Script
  }
  scope: siteResourceGroup
}
