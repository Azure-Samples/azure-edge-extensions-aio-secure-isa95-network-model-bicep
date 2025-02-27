// ------------------------------------------------------------
// Parameters - Core
// ------------------------------------------------------------

@description('The location targeted.')
param location string = resourceGroup().location

@description('The resource tags.')
param tags object = {}

// ------------------------------------------------------------
// Parameters - Virtual Machine (Cluster)
// ------------------------------------------------------------

@description('Specifies the name of the Virtual Machine.')
param name string

@description('Specifies the size of the Virtual Machine.')
param size string

@description('Specifies an image reference for the Virtual Machine.')
param imageReference object

@description('Specifies a username for the Virtual Machine.')
param adminUserName string

@description('Specifies the SSH public key.')
param adminPublicKey string

@description('Specifies managed identity resource ID for the Virtual Machine.')
param managedIdentityId string

@allowed([
  'Enabled'
  'Disabled'
])
@description('Specifies the status of the auto shutdown.')
param autoShutdownStatus string

@description('Specifies the time (24h HHmm format) of the auto shutdown.')
@minLength(4)
@maxLength(4)
param autoShutdownTime string

@description('Specifies the time zone of the auto shutdown.')
param autoShutdownTimeZoneId string

@description('Specifies the base64 encoded script to run on the Virtual Machine.')
param base64script string

// ------------------------------------------------------------
// Parameters - Network
// ------------------------------------------------------------

@description('The subnet resource id.')
param subnetId string

@description('Specifies the private IP address.')
param privateIPAddress string

// ------------------------------------------------------------
// Virtual Machine
// ------------------------------------------------------------

// create network interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${name}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAddress: privateIPAddress
          privateIPAllocationMethod: 'Static'
        }
      }
    ]
  }
}

// create virtual machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: name
      adminUsername: adminUserName
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUserName}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
        provisionVMAgent: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
        }
      }
    }
    securityProfile: {
      encryptionAtHost: true
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
  //checkov:skip=CKV_AZURE_50:Virtual Machine extensions are installed
}

// create auto shutdown configuration
resource autoShutdownConfig 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${name}'
  location: location
  properties: {
    status: autoShutdownStatus
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZoneId
    taskType: 'ComputeVmShutdownTask'
    targetResourceId: virtualMachine.id
  }
}

// create custom script extension
// https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux#troubleshooting
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'CustomScript'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      script: base64script
    }
  }
}
