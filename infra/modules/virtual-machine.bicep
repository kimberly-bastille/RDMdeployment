@description('Virtual Machine name')
param vmName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('VM size')
param vmSize string = 'Standard_B2s'

@description('Admin username for the VM')
param adminUsername string

@description('SSH public key for Linux authentication')
param sshPublicKey string

@description('Subnet ID for the VM')
param subnetId string

@description('Network Security Group ID')
param networkSecurityGroupId string = ''

@description('Managed identity ID for the VM')
param managedIdentityId string = ''

@description('Tags to apply to resources')
param tags object = {}

@description('Availability zone for the VM (1, 2, 3, or -1 for no zone)')
param availabilityZone int = -1

@description('Cloud-init configuration data (plain text, will be automatically base64 encoded)')
param cloudInitData string = ''

@description('Enable automatic installation of development tools (Azure CLI, kubectl, Helm)')
param installDevTools bool = true

@description('Enable Custom Script Extension for software installation')
param enableCustomScript bool = false

@description('Script file URI for Custom Script Extension')
param scriptFileUri string = ''

@description('Command to execute in Custom Script Extension')
param scriptCommand string = ''

// Generate cloud-init configuration for development tools
var devToolsCloudInit = '''
#cloud-config
package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - unzip
  - apt-transport-https
  - ca-certificates
  - gnupg

runcmd:
  # Install Azure CLI
  - curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  
  # Install kubectl
  - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  - sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  - rm kubectl
  
  # Install Helm
  - curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  - sudo apt-get update
  - sudo apt-get install -y helm
  
  # Set up bash completion
  - echo 'source <(kubectl completion bash)' >> /home/${adminUsername}/.bashrc
  - echo 'source <(helm completion bash)' >> /home/${adminUsername}/.bashrc
  - echo 'source /etc/bash_completion.d/azure-cli' >> /home/${adminUsername}/.bashrc
  
  # Create welcome message
  - echo "Azure CLI, kubectl, and Helm installed successfully!" > /home/${adminUsername}/welcome.txt
  - chown ${adminUsername}:${adminUsername} /home/${adminUsername}/welcome.txt

final_message: "Development tools installation complete!"
'''

// Choose cloud-init data: user-provided, dev tools, or none
var effectiveCloudInit = !empty(cloudInitData) ? cloudInitData : (installDevTools ? devToolsCloudInit : '')

// Use Azure Verified Module for Virtual Machine
module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.16.0' = {
  name: '${vmName}-vm-deployment'
  params: {
    // Required parameters
    adminUsername: adminUsername
    availabilityZone: availabilityZone
    imageReference: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    name: vmName
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: subnetId
            privateIPAllocationMethod: 'Dynamic'
            // No pipConfiguration specified = no public IP (private only for bastion access)
          }
        ]
        nicSuffix: '-nic'
        networkSecurityGroupResourceId: !empty(networkSecurityGroupId) ? networkSecurityGroupId : null
        enableAcceleratedNetworking: false // Disable for smaller VM sizes
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
      deleteOption: 'Delete'
    }
    osType: 'Linux'
    vmSize: vmSize

    // Optional parameters for security and configuration
    location: location
    tags: tags
    
    // Security: Enable encryption at host for all disks including temp disk
    encryptionAtHost: false
    
    // Cloud-init configuration for automated software installation
    customData: !empty(effectiveCloudInit) ? effectiveCloudInit : ''
    
    // Linux configuration with SSH key
    publicKeys: [
      {
        keyData: sshPublicKey
        path: '/home/${adminUsername}/.ssh/authorized_keys'
      }
    ]
    disablePasswordAuthentication: true // Use SSH keys only
    
    // Custom Script Extension for automated software installation
    extensionCustomScriptConfig: enableCustomScript ? {
      enabled: true
      fileData: !empty(scriptFileUri) ? [
        {
          uri: scriptFileUri
        }
      ] : []
      settings: !empty(scriptCommand) ? {
        commandToExecute: scriptCommand
      } : {}
    } : {
      enabled: false
      fileData: []
    }
    
    // Managed identity configuration
    managedIdentities: !empty(managedIdentityId) ? {
      userAssignedResourceIds: [
        managedIdentityId
      ]
    } : {}
  }
}

@description('Virtual Machine resource ID')
output vmId string = virtualMachine.outputs.resourceId

@description('Virtual Machine name')
output vmName string = virtualMachine.outputs.name

@description('Network Interface configurations')
output networkInterfaces array = virtualMachine.outputs.nicConfigurations
