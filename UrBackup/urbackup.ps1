# Will create an SSL cert stored in an Azure Keyvault through Let's Encrypt, using an automated DNS challenge
# If an SSL cert with the same name already exists, this script will cause a new version to be created in Keyvault
#
# Defaults to a B1s instance with 1 CPU and 1G RAM
#
# This script assumes you have:
# - The SSH Key for console login pre-generated, with the public key stored in a separate resource group in the same subscription
# - A "letsencrypt" user managed identity created in in a separate resource group in the same subscription
# - An Azure DNS Zone already created that:
#    - Has the "letsencrypt" user managed identity assigned the DNS Zone Contributor role
# - An Azure Keyvault that:
#    - Is set for Azure RBAC access (under Settings -> Access Policies)
#    - Has the "letsencrypt" user managed identity assigned the Key Vault Adminstrator role on the Keyvault (Access control IAM)
#    - Has 3 Secrets pre-populated in the keyvault
#      - FQDN (such as www.example.com)
#      - dns-root-zone (such as example.com)
#      - ssl-cert-name (name of the SSL cert to use in Azure)
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
$vmSetupScriptURL = "https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Letsencrypt/urbackup-ubuntu2204.sh"
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
    -TemplateFile "./letsencryptrenew.bicep" `
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