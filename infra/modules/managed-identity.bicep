// User-assigned managed identity for AKS and other services using Azure Verified Module
@description('Name of the managed identity')
param name string

@description('Location for the managed identity')
param location string

@description('Tags to apply to the managed identity')
param tags object = {}

// Create user-assigned managed identity using Azure Verified Module
module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${name}-managed-identity'
  params: {
    name: name
    location: location
    tags: tags
  }
}

// Outputs
output resourceId string = managedIdentity.outputs.resourceId
output principalId string = managedIdentity.outputs.principalId
output clientId string = managedIdentity.outputs.clientId
output name string = managedIdentity.outputs.name
