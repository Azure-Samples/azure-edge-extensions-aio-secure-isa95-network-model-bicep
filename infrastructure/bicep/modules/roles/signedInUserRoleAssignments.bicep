// ------------------------------------------------------------
// Parameters
// ------------------------------------------------------------

@description('The principal id.')
param principalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
@description('The principal type.')
param principalType string = 'ServicePrincipal'

@description('Specifies the name of the key vault.')
param keyVaultName string

@description('Specifies the name of the managed grafana.')
param managedGrafanaName string

// ------------------------------------------------------------
// Resources - Key Vault Role Assignments
// ------------------------------------------------------------

// get existing key vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// key vault secrets officer role definition
var keyVaultSecretsOfficerId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // #gitleaks:allow
@description('The built-in role for Key Vault Secrets Officer.')
resource keyVaultSecretsOfficerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: keyVaultSecretsOfficerId
}

// assign key vault secrets officer role to principalId
resource keyVaultSecretsOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, principalId, keyVaultSecretsOfficerRoleDefinition.id)
  properties: {
    roleDefinitionId: keyVaultSecretsOfficerRoleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}

// ------------------------------------------------------------
// Resources - Managed Grafana Role Assignments
// ------------------------------------------------------------

// get existing managed grafana
resource managedGrafana 'Microsoft.Dashboard/grafana@2023-09-01' existing = {
  name: managedGrafanaName
}

// grafana admin role definition
var grafanaAdminId = '22926164-76b3-42b3-bc55-97df8dab3e41' // #gitleaks:allow
@description('The built-in role for Grafana Admin.')
resource grafanaAdminRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: grafanaAdminId
}

// assign grafana admin role to principalId
resource grafanaAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: managedGrafana
  name: guid(managedGrafana.id, principalId, grafanaAdminRoleDefinition.id)
  properties: {
    roleDefinitionId: grafanaAdminRoleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}
