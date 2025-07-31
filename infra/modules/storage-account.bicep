// Azure Storage Account using Azure Verified Module
// This module uses the AVM Storage Account module v0.25.1 with enhanced security
// Features:
// - Private networking with endpoints for both blob and file services
// - File share with configurable name
// - Automatic private DNS zone creation and VNet linking
// - Zone-redundant storage for high availability
// - Comprehensive security settings and monitoring

@description('Name of the storage account')
param name string

@description('Location for the storage account')
param location string = resourceGroup().location

@description('Tags to apply to the storage account')
param tags object = {}

@description('Resource ID of the private subnet for private endpoint')
param privateSubnetResourceId string

@description('Name of the file share to create')
param fileShareName string

@description('Virtual Network resource ID for DNS zone linking')
param virtualNetworkResourceId string

// Create Private DNS Zones for Storage Account endpoints
module blobPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: '${name}-blob-dns-zone'
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${name}-blob-vnet-link'
        virtualNetworkResourceId: virtualNetworkResourceId
        registrationEnabled: false
      }
    ]
  }
}

module filePrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: '${name}-file-dns-zone'
  params: {
    name: 'privatelink.file.${environment().suffixes.storage}'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${name}-file-vnet-link'
        virtualNetworkResourceId: virtualNetworkResourceId
        registrationEnabled: false
      }
    ]
  }
}

// Deploy Storage Account using Azure Verified Module
module storageAccount 'br/public:avm/res/storage/storage-account:0.25.1' = {
  name: '${name}-deployment'
  params: {
    name: name
    location: location
    tags: tags
    
    // Storage account configuration
    skuName: 'Standard_ZRS'
    kind: 'StorageV2'
    accessTier: 'Hot'
    
    // Security settings
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    
    // Network ACLs for enhanced security
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    
    // File services configuration with custom file share
    fileServices: {
      shares: [
        {
          name: fileShareName
          accessTier: 'Hot'
          shareQuota: 1024 // 1TB quota
          enabledProtocols: 'SMB'
          rootSquash: 'NoRootSquash'
        }
      ]
    }
    
    // Private endpoints for both blob and file services
    privateEndpoints: [
      {
        name: '${name}-blob-pe'
        service: 'blob'
        subnetResourceId: privateSubnetResourceId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: blobPrivateDnsZone.outputs.resourceId
            }
          ]
        }
        tags: tags
      }
      {
        name: '${name}-file-pe'
        service: 'file'
        subnetResourceId: privateSubnetResourceId
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: filePrivateDnsZone.outputs.resourceId
            }
          ]
        }
        tags: tags
      }
    ]
    
    // Enable enhanced blob services
    blobServices: {
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
      containerDeleteRetentionPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 7
      changeFeedEnabled: false
      versioningEnabled: false
      lastAccessTimeTrackingPolicyEnabled: false
    }
  }
}

// Outputs
output resourceId string = storageAccount.outputs.resourceId
output name string = storageAccount.outputs.name
output primaryEndpoints object = storageAccount.outputs.serviceEndpoints
output privateEndpoints array = storageAccount.outputs.privateEndpoints
output blobPrivateDnsZoneResourceId string = blobPrivateDnsZone.outputs.resourceId
output filePrivateDnsZoneResourceId string = filePrivateDnsZone.outputs.resourceId
@secure()
output primaryAccessKey string = storageAccount.outputs.primaryAccessKey
@secure()
output primaryConnectionString string = storageAccount.outputs.primaryConnectionString
