# Will create an instance of Wordpress in a Docker Container
# Database is stored in an Azure Database for MySQL instance
# Files stored in an Azure File Share
#
# Defaults to a B1s instance with 1 CPU and 1G RAM
#
# This script assumes you have:
# - The SSH Key for console login pre-generated, with the public key stored in a separate resource group in the same subscription
# - A "wordpress" user managed identity created in in a separate resource group in the same subscription
# - An Azure Keyvault that:
#    - Is set for Azure RBAC access (under Settings -> Access Policies)
#    - Has the "wordpress" user managed identity assigned the Key Vault Secrets User role on the Keyvault (Access control IAM)
#    - Has 5 Secrets pre-populated in the keyvault
#      - ssl-cert-name (name of the SSL cert in the Azure Keyvault)
#      - FQDN (for your domain such as www.example.com, for Nginx reverse proxy)
#      - storageaccount-name
#      - storageaccount-rg
#
# Azure JSON schema for certificates can be found with:
# az keyvault certificate get-default-policy --scaffold


#############
# Variables #
#############

# General Variables
$projectName = "wordpress"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$rgName = "rg-$projectName"

# VM Creation Variables
$vmName = "TA1-SV11-Wordpress"
$sshkeyRgName = "rg-keyvault"  ## Name of the resource group in which you store your SSH login public keys
$sshkeyName = "vmkey"          ## Name of the public SSH key you want to use for the VM
$managedidentityResourceGroup = "rg-usermanagedidentities"
$managedidentityName = "wordpress"
$publicIPDomainName = "tabulawordpress"  ## DNS name for public IP (will concatenate [name].[region].cloudapp.azure.com) - must be global unique

# VM Setup Script Variables (passed into Bash using Custom Script Extension)
$vmSetupScriptURL = "https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Wordpress/wordpress-ubuntu2204.sh"
$vmTimeZone = "America/New_York"
$vmKeyVaultName = "keyvault-wordpress"  ## Name of the keyvault that stores the Secrets, and also where the SSL Cert will be stored

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
    -TemplateFile "./wordpress.bicep" `
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