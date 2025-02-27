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
param clusterAdminUserName string

@secure()
@description('Specifies admin public key.')
param clusterAdminPublicKey string

@description('Specifies image reference.')
param clusterImageReference object

@description('Specifies the size.')
param clusterSize string

@description('Specifies managed identity resource ID.')
param clusterManagedIdentityId string

@allowed([
  'Enabled'
  'Disabled'
])
@description('Specifies the status of the auto shutdown.')
param clusterAutoShutdownStatus string

@description('Specifies the time (24h HHmm format) of the auto shutdown.')
@minLength(4)
@maxLength(4)
param clusterAutoShutdownTime string

@description('Specifies the time zone of the auto shutdown.')
param clusterAutoShutdownTimeZoneId string

@description('Specifies the base64 encoded script to run on the Virtual Machine.')
param clusterBase64Script string

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

module corpClusterModule './workloads/corp/cluster.bicep' = {
  name: 'corp-cluster'
  params: {
    location: location
    prefix: prefix
    id: id
    environment: environment
    network: network
    vnetName: vnetName
    vnetResourceGroupName: vnetResourceGroupName
    clusterAdminUserName: clusterAdminUserName
    clusterAdminPublicKey: clusterAdminPublicKey
    clusterImageReference: clusterImageReference
    clusterSize: clusterSize
    clusterManagedIdentityId: clusterManagedIdentityId
    clusterAutoShutdownStatus: clusterAutoShutdownStatus
    clusterAutoShutdownTime: clusterAutoShutdownTime
    clusterAutoShutdownTimeZoneId: clusterAutoShutdownTimeZoneId
    clusterBase64Script: clusterBase64Script
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

module siteClusterModule './workloads/site/cluster.bicep' = {
  name: 'site-cluster'
  params: {
    location: location
    prefix: prefix
    id: id
    environment: environment
    network: network
    vnetName: vnetName
    vnetResourceGroupName: vnetResourceGroupName
    clusterAdminUserName: clusterAdminUserName
    clusterAdminPublicKey: clusterAdminPublicKey
    clusterImageReference: clusterImageReference
    clusterSize: clusterSize
    clusterManagedIdentityId: clusterManagedIdentityId
    clusterAutoShutdownStatus: clusterAutoShutdownStatus
    clusterAutoShutdownTime: clusterAutoShutdownTime
    clusterAutoShutdownTimeZoneId: clusterAutoShutdownTimeZoneId
    clusterBase64Script: clusterBase64Script
  }
  scope: siteResourceGroup
}
