// Azure Key Vault using Azure Verified Module (AVM)
@description('Name of the Key Vault')
param name string

@description('Location for the Key Vault')
param location string

@description('Tags to apply to the Key Vault')
param tags object = {}

@description('Object ID of the admin user/group for Key Vault access')
param adminObjectId string

@description('Resource ID of the private subnet for private endpoint')
param privateSubnetResourceId string

@description('Resource ID of the virtual network for DNS zone linking')
param virtualNetworkResourceId string

@description('Principal ID of the managed identity for Key Vault access')
param managedIdentityPrincipalId string

// Create private DNS zone for Key Vault first
module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: '${name}-dns-zone-deployment'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: virtualNetworkResourceId
        registrationEnabled: false
      }
    ]
  }
}

// Deploy Azure Key Vault using AVM module
module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  name: '${name}-deployment'
  params: {
    name: name
    location: location
    tags: tags
    sku: 'standard'
    enableSoftDelete: true
    enablePurgeProtection: true
    enableVaultForTemplateDeployment: true
    enableVaultForDeployment: true
    enableVaultForDiskEncryption: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    
    // Configure private endpoint with DNS zone
    privateEndpoints: [
      {
        subnetResourceId: privateSubnetResourceId
        name: '${name}-pe'
        service: 'vault'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    
    // Configure RBAC role assignments
    roleAssignments: [
      // Admin access via RBAC
      {
        principalId: adminObjectId
        principalType: 'User'
        roleDefinitionIdOrName: 'Key Vault Administrator'
      }
      // Managed identity access for Application Gateway
      {
        principalId: managedIdentityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      // Additional certificate access for Application Gateway
      {
        principalId: managedIdentityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Certificate User'
      }
    ]
  }
}

// Outputs
output resourceId string = keyVault.outputs.resourceId
output name string = keyVault.outputs.name
output vaultUri string = keyVault.outputs.uri
output privateDnsZoneResourceId string = privateDnsZone.outputs.resourceId
