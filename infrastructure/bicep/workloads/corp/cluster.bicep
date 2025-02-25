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
param workload string = 'corp'

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

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: network.subnets.corp.name
}

// ------------------------------------------------------------
// Resources - Virtual Machine (Cluster)
// ------------------------------------------------------------

module vmCluster '../../modules/virtualMachineCluster.bicep' = {
  name: 'add-vmcluster'
  params: {
    location: location
    tags: resourceTags
    name: 'cluster${resourceSuffix}'
    size: clusterSize
    imageReference: clusterImageReference
    adminUserName: clusterAdminUserName
    adminPublicKey: clusterAdminPublicKey
    managedIdentityId: clusterManagedIdentityId
    autoShutdownStatus: clusterAutoShutdownStatus
    autoShutdownTime: clusterAutoShutdownTime
    autoShutdownTimeZoneId: clusterAutoShutdownTimeZoneId
    base64script: clusterBase64Script
    subnetId: subnet.id
    privateIPAddress: network.subnets.corp.cluster.privateIPAddress
  }
}
