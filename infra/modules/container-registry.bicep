// Azure Container Registry using Azure Verified Module (AVM)
@description('Name of the Container Registry')
param name string

@description('Location for the Container Registry')
param location string

@description('Tags to apply to the Container Registry')
param tags object = {}

@description('Resource ID of the private subnet for private endpoint')
param privateSubnetResourceId string

@description('Resource ID of the virtual network for DNS zone linking')
param virtualNetworkResourceId string

@description('Principal ID of the managed identity for ACR pull access')
param managedIdentityPrincipalId string

// Create private DNS zone for Container Registry first
module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: '${name}-dns-zone-deployment'
  params: {
    name: 'privatelink.azurecr.io'
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

// Deploy Azure Container Registry using AVM module
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: '${name}-deployment'
  params: {
    name: name
    location: location
    tags: tags
    acrSku: 'Premium'
    acrAdminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSetDefaultAction: 'Deny'
    zoneRedundancy: 'Disabled'
    
    
    // Configure private endpoint with DNS zone
    privateEndpoints: [
      {
        subnetResourceId: privateSubnetResourceId
        name: '${name}-pe'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    
    // Configure role assignments for managed identity
    roleAssignments: [
      {
        principalId: managedIdentityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'AcrPull'
      }
    ]
  }
}

// Outputs
output resourceId string = containerRegistry.outputs.resourceId
output name string = containerRegistry.outputs.name
output loginServer string = containerRegistry.outputs.loginServer
output privateDnsZoneResourceId string = privateDnsZone.outputs.resourceId
