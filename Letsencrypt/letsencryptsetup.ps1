# Will generate an SSL cert through Let's Encrypt and store in Azure Keyvault
#
# Defaults to a B1s instance with 1 CPU and 1G RAM
#
# This script assumes you have:
# - The SSH Key for console login pre-generated, with the public key stored in a separate resource group in the same subscription
# - A "letsencrypt" user managed identity created in in a separate resource group in the same subscription
# - An Azure Keyvault that:
#    - Is set for Azure RBAC access (under Settings -> Access Policies)
#    - Has the "letsencrypt" user managed identity assigned the Key Vault Adminstrator role on the Keyvault (Access control IAM)
#    - Has 2 secrets pre-populated in the keyvault
#      - letsencrypt-email
#      - FQDN
# - DNS records properly pointed to the FQDN you have specified
#
# JSON schema for certificates can be found with:
# az keyvault certificate get-default-policy --scaffold


#############
# Variables #
#############

# General Variables
$projectName = "letsencrypt"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$rgName = "rg-$projectName"

# VM Creation Variables
$vmName = "TA1-SV99-Letsencrypt"
$sshkeyRgName = "rg-keyvault"  ## Name of the resource group that you store your SSH keys in
$sshkeyName = "vmkey"          ## Name of the public SSH key you want to use for the VM
$managedidentityResourceGroup = "rg-usermanagedidentities"
$managedidentityName = "letsencrypt"
$publicIPDomainName = "letsencrypt227"  ## DNS name for public IP (will concatenate [name].[region].cloudapp.azure.com) - must be global unique

# VM Setup Script Variables (passed into Bash using Custom Script Extension)
$vmSetupScriptURL = "https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Letsencrypt/letsencryptsetup-ubuntu2204.sh"
$vmTimeZone = "America/New_York"
$vmSwapFileSize = "1G"
$vmKeyVaultName = "keyvault-elastic"
$sslCertName = "sslcert-elastic"

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
    -ResourceGroupName $rgName `
    -TemplateFile "./letsencryptsetup.bicep" `
    -projectName $projectName `
    -projectLocation $projectLocation `
    -vmName $vmName `
    -sshpublickey $sshkey.publicKey `
    -vmSetupScriptURL $vmSetupScriptURL `
    -managedidentityID $managedidentityID.Id `
    -vmTimeZone $vmTimeZone `
    -vmSwapFileSize $vmSwapFileSize `
    -vmKeyVaultName $vmKeyVaultName `
    -sslCertName $sslCertName `
    -publicIPDomainName $publicIPDomainName