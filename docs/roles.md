# Role Assignments

This document lists all the role assignments provided in the Bicep modules.

## Identity: Signed-In User

This identity is used to deploy the main infrastructure. It can be an interactive user or a service principal.

### Key Vault Secrets Officer

- **Role Definition ID**: [b86a8fe4-44ce-4948-aee5-eccb2c155cd7](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer)
- **Description**: Perform any action on the secrets of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model.
- **Scope**: Key Vault

### Grafana Admin

- **Role Definition ID**: [22926164-76b3-42b3-bc55-97df8dab3e41](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/monitor#grafana-admin)
- **Description**: Manage server-wide settings and manage access to resources such as organizations, users, and licenses.
- **Scope**: Managed Grafana

## Identity: Cluster Managed Identity

This identity is used by the virtual machine hosting the Kubernetes cluster.

### Azure Arc Onboarding

- **Role Definition ID**: [34e09817-6cbe-4d01-b1a2-e0eac5743d41](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/containers#kubernetes-cluster---azure-arc-onboarding)
- **Description**: Role definition to authorize any user/service to create connectedClusters resource.
- **Scope**: Resource Group

### Kubernetes Extension Contributor

- **Role Definition ID**: [85cb6faf-e071-4c9b-8136-154b5a04f717](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/containers#kubernetes-extension-contributor)
- **Description**:  Can create, update, get, list and delete Kubernetes Extensions, and get extension async operations.
- **Scope**: Resource Group

### Monitoring Contributor

- **Role Definition ID**: [749f88d5-cbae-40b8-bcfc-e573ddc772fa](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/monitor#monitoring-contributor)
- **Description**:  Can read all monitoring data and edit monitoring settings.
- **Scope**: Resource Group

### Key Vault Secrets Officer

- **Role Definition ID**: [b86a8fe4-44ce-4948-aee5-eccb2c155cd7](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer)
- **Description**: Perform any action on the secrets of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model.
- **Scope**: Key Vault

### App Configuration Contributor

- **Role Definition ID**: [fe86443c-f201-4fc4-9d2a-ac61149fbda0](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/integration#app-configuration-contributor)
- **Description**: Grants permission for all management operations, except purge, for App Configuration resources.
- **Scope**: App Configuration

## Identity: Proxy Managed Identity

### Key Vault Secrets Officer

- **Role Definition ID**: [b86a8fe4-44ce-4948-aee5-eccb2c155cd7](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer)
- **Description**: Perform any action on the secrets of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model.
- **Scope**: Key Vault

### App Configuration Contributor

- **Role Definition ID**: [fe86443c-f201-4fc4-9d2a-ac61149fbda0](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/integration#app-configuration-contributor)
- **Description**: Grants permission for all management operations, except purge, for App Configuration resources.
- **Scope**: App Configuration
