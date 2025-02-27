// ------------------------------------------------------------
// Parameters
// ------------------------------------------------------------

@description('The principal ID.')
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

@description('Specifies the name of the app configuration.')
param appConfigurationName string

@description('Specifies the name of the managed grafana.')
param managedGrafanaName string

// ------------------------------------------------------------
// Resources - Resource Group Role Assignments
// ------------------------------------------------------------

// azure arc onboarding role definition
var arcOnboardingId = '34e09817-6cbe-4d01-b1a2-e0eac5743d41' // #gitleaks:allow
@description('The built-in role for Kubernetes Cluster - Azure Arc Onboarding.')
resource arcOnboardingRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: arcOnboardingId
}

// assign arc onboarding role to principalId
resource arcOnboardingRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, principalId, arcOnboardingRoleDefinition.id)
  properties: {
    roleDefinitionId: arcOnboardingRoleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}

// kubernetes extension contributor role definition
var kubernetesExtensionContributorId = '85cb6faf-e071-4c9b-8136-154b5a04f717' // #gitleaks:allow
@description('The built-in role for Kubernetes Extension Contributor.')
resource kubernetesExtensionContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: kubernetesExtensionContributorId
}

// assign kubernetes extension contributor role to principalId
resource kubernetesExtensionContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, principalId, kubernetesExtensionContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: kubernetesExtensionContributorRoleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}

// monitoring contributor role definition
var monitoringContributorId='749f88d5-cbae-40b8-bcfc-e573ddc772fa' // #gitleaks:allow
@description('The built-in role for Monitoring Contributor.')
resource monitoringContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: monitoringContributorId
}

// assign monitoring contributor role to principalId
resource monitoringContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, principalId, monitoringContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: monitoringContributorRoleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}

// ------------------------------------------------------------
// Resources - Key Vault Role Assignments
// ------------------------------------------------------------

// get existing key vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// key vault secrets officer role definition
var keyVaultSecretsOfficerId='b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // #gitleaks:allow
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
// Resources - App Configuration Role Assignments
// ------------------------------------------------------------

// get existing app configuration
resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = {
  name: appConfigurationName
}

// app configuration contributor role definition
var appConfigurationContributorId='fe86443c-f201-4fc4-9d2a-ac61149fbda0' // #gitleaks:allow
@description('The built-in role for App Configuration Contributor.')
resource appConfigurationContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: appConfigurationContributorId
}

// assign app configuration contributor role to principalId
resource appConfigurationContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appConfiguration
  name: guid(appConfiguration.id, principalId, appConfigurationContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: appConfigurationContributorRoleDefinition.id
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

// grafana workspace contributor role definition
var grafanaWorkspaceContributorId = '5c2d7e57-b7c2-4d8a-be4f-82afa42c6e95' // #gitleaks:allow
@description('The built-in role for Grafana Workspace Contributor.')
resource grafanaWorkspaceContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: grafanaWorkspaceContributorId
}

// assign grafana workspace contributor role to principalId
resource grafanaWorkspaceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: managedGrafana
  name: guid(managedGrafana.id, principalId, grafanaWorkspaceContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: grafanaWorkspaceContributorRoleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}
