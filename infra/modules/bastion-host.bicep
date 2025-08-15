@description('Bastion Host name')
param bastionName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual Network resource ID for Azure Bastion')
param virtualNetworkResourceId string

@description('Tags to apply to the Bastion Host')
param tags object = {}

// Deploy Azure Bastion using the verified module with minimal defaults
module bastionHost 'br/public:avm/res/network/bastion-host:0.7.0' = {
  name: 'bastionHostDeployment'
  params: {
    // Required parameters
    name: bastionName
    virtualNetworkResourceId: virtualNetworkResourceId
    // Optional parameters - using AVM defaults
    location: location
    tags: tags
  }
}

@description('Bastion Host resource ID')
output bastionId string = bastionHost.outputs.resourceId

@description('Bastion Host name')
output bastionName string = bastionHost.outputs.name

@description('Bastion Host location')
output location string = bastionHost.outputs.location
