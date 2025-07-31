# Infra

## File Setup

1. Copy the example environment file and parameters file to create your working configuration:
  ```bash
  cp .env.example .env
  cp main.parameters.example.json main.parameters.json
  ```
2. Edit `.env` and `main.parameters.json` as needed for your environment.


## Prerequisites

1. Install Azure CLI
2. Login to Azure:
   ```bash
   az login
   ```

3. Generate SSH key pair (if you don't have one):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
   ```
   - Press Enter to accept the default file location
   - Enter a passphrase (optional but recommended)
   - Copy the public key content:
     ```bash
     cat ~/.ssh/id_rsa.pub
     ```
   - Update the `sshPublicKey` value in `main.parameters.json` with the copied public key

4. Get your Azure user object ID for Key Vault access:
   ```bash
   # Get your current user's object ID
   az ad signed-in-user show --query id -o tsv
   ```
   - Copy the returned object ID
   - Update the `keyVaultAdminObjectId` value in `main.parameters.json` with this object ID

5. Set environment variables:
   ```bash
   source .env
   ```

6. Set the correct subscription:
   ```bash
   az account set --subscription "$SUBSCRIPTION_ID"
   ```

## VM Automatic Software Installation

The VM module now supports **automatic installation** of development tools (Azure CLI, kubectl, and Helm) during VM creation. This is **enabled by default** and requires no additional configuration!

### **Option 1: Default Automatic Installation (Recommended)**

By default, the VM will automatically install Azure CLI, kubectl, and Helm when it starts up. No additional steps required!

```json
// In main.parameters.json - these tools install automatically
{
  "adminUsername": {
    "value": "localuser"
  }
  // installDevTools defaults to true - no need to specify
}
```

### **Option 2: Disable Automatic Installation**

If you don't want the development tools installed automatically:

```json
{
  "installDevTools": {
    "value": false
  }
}
```


### **Verify Installation**

After VM deployment, SSH to the VM and check:
```bash
az --version
kubectl version --client
helm version
```

The installation creates a welcome message at `/home/{username}/welcome.txt` with confirmation.

## Deployment Commands

1. Validate the Bicep template:
   ```bash
   az deployment group validate \
     --resource-group "$RESOURCE_GROUP" \
     --template-file main.bicep \
     --parameters @main.parameters.json
   ```

2. Deploy the infrastructure:
   ```bash
   az deployment group create \
     --resource-group "$RESOURCE_GROUP" \
     --template-file main.bicep \
     --parameters @main.parameters.json
   ```
