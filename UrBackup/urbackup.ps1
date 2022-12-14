# Will create an instance of UrBackup in a Docker Container, with the backups destination set to an Azure File Share
#
# Defaults to a B1ls instance with 1 CPU and 512M RAM
#
# This script assumes you have:
# - The SSH Key for console login pre-generated, with the public key stored in a separate resource group in the same subscription
# - A "urbackup" user managed identity created in in a separate resource group in the same subscription
# - An Azure Keyvault that:
#    - Is set for Azure RBAC access (under Settings -> Access Policies)
#    - Has the "urbackup" user managed identity assigned the Key Vault Secrets User role on the Keyvault (Access control IAM)
#    - Has 3 Secrets pre-populated in the keyvault
#      - storage-account-rg (resource group containing the storage account that holds the file share)
#      - storage-account-name (name of the storage account that holds the file share)
#      - ssl-cert-name (name of the SSL cert in the Azure Keyvault)
# - An Azure Storage Account that:
#    - Has the "urbackup" user managed identity assigned Storage Account Key Operator and Storage File Data SMB Share Contributor roles
#    - Has a file share named fileshare-urbackup created
#
# Azure JSON schema for certificates can be found with:
# az keyvault certificate get-default-policy --scaffold


#############
# Variables #
#############

# General Variables
$projectName = "urbackup"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$rgName = "rg-$projectName"

# VM Creation Variables
$vmName = "TA1-SV99-UrBackup"
$sshkeyRgName = "rg-keyvault"  ## Name of the resource group in which you store your SSH login public keys
$sshkeyName = "vmkey"          ## Name of the public SSH key you want to use for the VM
$managedidentityResourceGroup = "rg-usermanagedidentities"
$managedidentityName = "urbackup"
$publicIPDomainName = "urbackup227"  ## DNS name for public IP (will concatenate [name].[region].cloudapp.azure.com) - must be global unique

# VM Setup Script Variables (passed into Bash using Custom Script Extension)
$vmSetupScriptURL = "https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/UrBackup/urbackup-ubuntu2204.sh"
$vmTimeZone = "America/New_York"
$vmKeyVaultName = "keyvault-urbackup"  ## Name of the keyvault that stores the Secrets, and also where the SSL Cert will be stored

##################
# Start of Setup #
##################

# Set Correct Subscription
Set-AzContext $subscriptionName

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $projectLocation

# Get SSH Public Key from Existing Resource Group, to use when setting up VM
$sshkey = Get-AzSshKey -ResourceGroupName $sshkeyRgName -Name $sshkeyName

# Get Managed Identity ID, allows for login to Azure AD to access Keyvault
$managedidentityID = Get-AzUserAssignedIdentity -Name $managedidentityName -ResourceGroupName $managedidentityResourceGroup

# Deploy Bicep template using variables listed above
New-AzResourceGroupDeployment `
    -Verbose `
    -ResourceGroupName $rgName `
    -TemplateFile "./urbackup.bicep" `
    -projectName $projectName `
    -projectLocation $projectLocation `
    -vmName $vmName `
    -sshpublickey $sshkey.publicKey `
    -vmSetupScriptURL $vmSetupScriptURL `
    -managedidentityID $managedidentityID.Id `
    -managedidentityClientID $managedidentityID.ClientId `
    -vmTimeZone $vmTimeZone `
    -vmKeyVaultName $vmKeyVaultName `
    -publicIPDomainName $publicIPDomainName