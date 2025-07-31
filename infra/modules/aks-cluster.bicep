// Azure Kubernetes Service private cluster with native Bicep template
// Using userDefinedRouting outbound type for custom network routing scenarios
@description('Name of the AKS cluster')
param name string

@description('Location for the AKS cluster')
param location string

@description('Tags to apply to the AKS cluster')
param tags object = {}

@description('Kubernetes version')
param kubernetesVersion string

@description('Resource ID of the AKS node pool subnet')
param aksNodePoolSubnetResourceId string

@description('Resource ID of the managed identity')
param managedIdentityResourceId string

@description('Number of nodes in the system node pool')
param systemNodeCount int

@description('VM size for system nodes')
param systemVmSize string

@description('VM size for shiny workload nodes')
param shinyVmSize string

@description('Whether to create the shiny user node pool')
param createShinyNodePool bool = false

// Create AKS cluster using native Bicep template
// Documentation: https://learn.microsoft.com/en-us/azure/aks/private-clusters
// Reference: https://learn.microsoft.com/en-us/azure/aks/egress-outboundtype#outbound-types-in-aks
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: name
  location: location
  tags: tags
  
  // Configure managed identity for the cluster
  // Best practice: Use user-assigned managed identity for better control
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResourceId}': {}
    }
  }
  
  properties: {
    // Kubernetes configuration
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${name}-dns'
    
    // Node resource group configuration
    // AKS will create resources like VMs, disks, NICs in this group
    nodeResourceGroup: '${resourceGroup().name}-aks-nodes'
    
    // Private cluster configuration
    // Reference: https://learn.microsoft.com/en-us/azure/aks/private-clusters
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system' // Let AKS manage the private DNS zone
      enablePrivateClusterPublicFQDN: false // No public FQDN for security
    }
    
    // Disable local accounts and enforce Azure AD authentication
    disableLocalAccounts: false
    
    // Network configuration with Azure CNI Overlay and userDefinedRouting
    // Reference: https://learn.microsoft.com/en-us/azure/aks/configure-azure-cni-overlay
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay' // Enables Azure CNI Overlay
      networkDataplane: 'azure'
      podCidr: '10.10.0.0/16' // Pod IP range for overlay network
      serviceCidr: '10.100.0.0/16' // Service IP range
      dnsServiceIP: '10.100.0.10' // DNS service IP within service CIDR
      outboundType: 'userDefinedRouting' // Use custom routing (UDR)
      loadBalancerSku: 'standard' // Required for UDR
      // No loadBalancerProfile specified when using userDefinedRouting
      // This avoids the InvalidUserDefinedRoutingWithLoadBalancerProfile error
    }
    
    // System node pool configuration
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: systemNodeCount
        vmSize: systemVmSize
        type: 'VirtualMachineScaleSets'
        mode: 'System' // System node pool for core components
        osType: 'Linux'
        osSKU: 'Ubuntu'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        vnetSubnetID: aksNodePoolSubnetResourceId
        maxPods: 250
        enableAutoScaling: true
        minCount: 1
        maxCount: 3
        enableNodePublicIP: false
        upgradeSettings: {
          maxSurge: '1'
        }
        // No availability zones specified - let Azure choose
      }
    ]
    
    // Auto upgrade configuration
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    
    // Azure Monitor integration for observability
    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
    }
    
    // Security profile with workload identity
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    
    // OIDC issuer for workload identity federation
    oidcIssuerProfile: {
      enabled: true
    }
  }
}

// Create additional user node pool for shiny workloads if requested
// Conditional deployment based on createShinyNodePool parameter
resource shinyNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-09-01' = if (createShinyNodePool) {
  parent: aksCluster
  name: 'shinypool'
  properties: {
    count: 0 // Start with 0 nodes, scale up as needed
    vmSize: shinyVmSize
    type: 'VirtualMachineScaleSets'
    mode: 'User' // User node pool for application workloads
    osType: 'Linux'
    osSKU: 'Ubuntu'
    osDiskSizeGB: 128
    osDiskType: 'Ephemeral' // Better performance for stateless workloads
    vnetSubnetID: aksNodePoolSubnetResourceId
    maxPods: 250
    enableAutoScaling: true
    minCount: 0
    maxCount: 30
    enableNodePublicIP: false
    scaleDownMode: 'Delete' // Delete nodes when scaling down
    nodeLabels: {
      sku: 'fx' // Label for workload scheduling
    }
    nodeTaints: [
      'sku=fx:NoSchedule' // Taint to ensure only specific workloads run here
    ]
    upgradeSettings: {
      maxSurge: '1'
    }
  }
}

// Outputs
// Reference native Bicep resource properties instead of module outputs
output resourceId string = aksCluster.id
output name string = aksCluster.name
