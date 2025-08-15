// Main Bicep template for NOAA RDM Tool Infrastructure
// This template deploys the complete infrastructure for the recreational fisheries decision support tool
targetScope = 'resourceGroup'

@description('Environment name (e.g., dev, staging, prod)')
param environmentName string = 'prod'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Unique resource token for naming consistency')
param resourceToken string = uniqueString(subscription().id, resourceGroup().id)

// Existing VNET configuration parameters
@description('Resource ID of the existing virtual network')
param virtualNetworkResourceId string

@description('Resource ID of the existing private subnet')
param privateSubnetResourceId string

// @description('Resource ID of the existing public subnet')
// param appGatewaySubnetResourceId string

// Authentication and security parameters
@description('SSH public key for Linux VMs')
param sshPublicKey string

@description('Admin username for VMs')
param adminUsername string = 'localuser'

// @description('Object ID of the Azure AD group for Key Vault access')
// param keyVaultAdminObjectId string

// @description('Custom domain name for the application')
// param customDomainName string = 'test.com'

// VM configuration
@description('VM size for the Linux VM')
param vmSize string = 'Standard_DS2_v2'

// Kubernetes configuration
@description('Kubernetes version for AKS cluster')
param kubernetesVersion string = '1.33.1'

@description('Resource ID of the AKS node pool subnet')
param aksNodePoolSubnetResourceId string

@description('Node count for the system node pool')
param systemNodeCount int = 3

@description('VM size for system nodes')
param systemVmSize string = 'Standard_DS2_v2'

@description('VM size for shiny workload nodes')
param userVmSize string = 'Standard_FX36mds'

@description('Whether to create the shiny user node pool')
param createShinyNodePool bool = false

// Common tags for all resources
var tags = {
  Environment: environmentName
}

// Resource naming convention
var naming = {
  resourceGroup: resourceGroup().name
  managedIdentity: 'mi-${environmentName}-${resourceToken}'
  keyVault: 'kv-${environmentName}-${resourceToken}'
  containerRegistry: 'acr${environmentName}${resourceToken}'
  aksCluster: 'aks-${environmentName}-cluster'
  applicationGateway: 'agw-${environmentName}'
  storageAccount: 'st${environmentName}${resourceToken}'
  virtualMachine: 'vm-linux-${environmentName}'
  bastionHost: 'bastion2-${environmentName}'
  // dnsZone: customDomainName
}

// Deploy user-assigned managed identity for AKS
module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'managedIdentity'
  params: {
    name: naming.managedIdentity
    location: location
    tags: tags
  }
}

// Deploy Key Vault for certificates and secrets
// module keyVault 'modules/key-vault.bicep' = {
//   name: 'keyVault'
//   params: {
//     name: naming.keyVault
//     location: location
//     tags: tags
//     adminObjectId: keyVaultAdminObjectId
//     privateSubnetResourceId: privateSubnetResourceId
//     virtualNetworkResourceId: virtualNetworkResourceId
//     managedIdentityPrincipalId: managedIdentity.outputs.principalId
//   }
// }

// Deploy Azure Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'containerRegistry'
  params: {
    name: naming.containerRegistry
    location: location
    tags: tags
    privateSubnetResourceId: privateSubnetResourceId
    virtualNetworkResourceId: virtualNetworkResourceId
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
  }
}

// Deploy storage account for data
module storageAccount 'modules/storage-account.bicep' = {
  name: 'storageAccount'
  params: {
    name: naming.storageAccount
    location: location
    tags: tags
    privateSubnetResourceId: privateSubnetResourceId
    fileShareName: 'noaa-rdm-data'
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

// Deploy AKS cluster
module aksCluster 'modules/aks-cluster.bicep' = {
  name: 'aksCluster'
  params: {
    name: naming.aksCluster
    location: location
    kubernetesVersion: kubernetesVersion
    aksNodePoolSubnetResourceId: aksNodePoolSubnetResourceId
    managedIdentityResourceId: managedIdentity.outputs.resourceId
    systemNodeCount: systemNodeCount
    systemVmSize: systemVmSize
    shinyVmSize: userVmSize
    createShinyNodePool: createShinyNodePool
    tags: tags
  }
}

// Deploy Application Gateway
// module applicationGateway 'modules/application-gateway.bicep' = {
//   name: 'applicationGateway'
//   params: {
//     appGatewayName: naming.applicationGateway
//     location: location
//     subnetId: appGatewaySubnetResourceId
//     keyVaultId: keyVault.outputs.resourceId
//     sslCertificateSecretName: 'ssl-certificate'
//     managedIdentityId: managedIdentity.outputs.resourceId
//     customDomain: customDomainName
//     tags: tags
//   }
// }

// Deploy Virtual Machine
module virtualMachine 'modules/virtual-machine.bicep' = {
  name: 'virtualMachine'
  params: {
    vmName: naming.virtualMachine
    location: location
    vmSize: vmSize
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: privateSubnetResourceId
    networkSecurityGroupId: ''
    managedIdentityId: managedIdentity.outputs.resourceId
    tags: tags
  }
}

// Deploy Bastion Host
module bastionHost 'modules/bastion-host.bicep' = {
  name: 'bastionHost'
  params: {
    bastionName: naming.bastionHost
    location: location
    virtualNetworkResourceId: virtualNetworkResourceId
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output managedIdentityResourceId string = managedIdentity.outputs.resourceId
output managedIdentityClientId string = managedIdentity.outputs.clientId
// output keyVaultName string = keyVault.outputs.name
// output keyVaultResourceId string = keyVault.outputs.resourceId
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output aksClusterName string = aksCluster.outputs.name
// output applicationGatewayName string = applicationGateway.outputs.applicationGatewayName
// output applicationGatewayPrivateIp string = applicationGateway.outputs.privateIpAddress
output storageAccountName string = storageAccount.outputs.name
output virtualMachineName string = virtualMachine.outputs.vmName
output bastionHostName string = bastionHost.outputs.bastionName
