// Application Gateway with Private-Only Deployment (Preview)
// This configuration uses the Azure Application Gateway Private Deployment preview feature
// which allows Application Gateway v2 to have only a private frontend IP configuration
// without requiring a public IP address.
// 
// Prerequisites:
// - Subscription must be enrolled in the preview: Microsoft.Network/EnableApplicationGatewayNetworkIsolation
// - Uses Standard_v2 or WAF_v2 SKU which supports the private deployment feature
// 
// Key Benefits:
// - No public IP required
// - Enhanced security with private-only access
// - Full control over NSG and route table configuration
// - Eliminates need for GatewayManager service tag rules
// - Azure automatically adds EnhancedNetworkControl: True tag after deployment

@description('Application Gateway name')
param appGatewayName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Subnet ID for Application Gateway')
param subnetId string

@description('Private IP address for Application Gateway frontend (optional)')
param privateIpAddress string = ''

@description('Key Vault ID for SSL certificate')
param keyVaultId string

@description('SSL certificate secret name in Key Vault')
param sslCertificateSecretName string

@description('Managed identity ID for Key Vault access')
param managedIdentityId string

@description('Backend pool addresses (FQDN or IP)')
param backendAddresses array = []

@description('Custom domain name for the application')
param customDomain string = 'recdst.noaa.gov'

@description('Tags to apply to the Application Gateway')
param tags object = {}

resource applicationGateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: appGatewayName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 10
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    // Private-only frontend IP configuration (Preview feature)
    // This eliminates the need for a public IP address and enables enhanced network controls
    frontendIPConfigurations: [
      {
        name: 'appGwPrivateFrontendIp'
        properties: {
          privateIPAllocationMethod: empty(privateIpAddress) ? 'Dynamic' : 'Static'
          privateIPAddress: empty(privateIpAddress) ? null : privateIpAddress
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultAddressPool'
        properties: {
          backendAddresses: backendAddresses
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPrivateFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
          }
          protocol: 'Http'
        }
      }
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPrivateFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
          }
          protocol: 'Https'
          hostName: customDomain
          requireServerNameIndication: true
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'appGatewaySslCert')
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'httpToHttpsRedirectRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          redirectConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', appGatewayName, 'httpToHttpsRedirect')
          }
        }
      }
      {
        name: 'httpsRule'
        properties: {
          ruleType: 'Basic'
          priority: 200
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpsListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'defaultAddressPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'defaultHttpSettings')
          }
        }
      }
    ]
    redirectConfigurations: [
      {
        name: 'httpToHttpsRedirect'
        properties: {
          redirectType: 'Permanent'
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpsListener')
          }
          includePath: true
          includeQueryString: true
        }
      }
    ]
    sslCertificates: [
      {
        name: 'appGatewaySslCert'
        properties: {
          keyVaultSecretId: '${keyVaultId}/secrets/${sslCertificateSecretName}'
        }
      }
    ]
    enableHttp2: true
    trustedRootCertificates: []
    sslProfiles: []
    enableFips: false
    forceFirewallPolicyAssociation: false
  }
}

@description('Application Gateway resource ID')
output applicationGatewayId string = applicationGateway.id

@description('Application Gateway name')
output applicationGatewayName string = applicationGateway.name

@description('Application Gateway private IP address')
output privateIpAddress string = applicationGateway.properties.frontendIPConfigurations[0].properties.privateIPAddress
