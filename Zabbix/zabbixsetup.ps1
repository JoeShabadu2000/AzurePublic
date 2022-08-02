# Setup script for Zabbix on Azure
#
# Installs all Zabbix files and MySQL server on the same VM for ease of setup
# Also uses certbot to generate HTTPS certificate w/ auto renewal through Letsencrypt
# Should just be able to run this script, then visit https://yoururl.azure.com/ to complete setup
# 
# What does it do?
# 
# - Creates a new resource group in Azure
#
# - Uses Powershell to deploy a Bicep template that creates:
#   - Vnet and Subnet
#   - Public IP Address
#   - Network Security Group
#   - NIC
#   - VM running Ubuntu 22.04 w/ Custom Script Extension for Linux
#
# - VM Bash setup script:
#   - Bash script is hosted on Github public repo, contains no secrets
#   - Bicep template specifies function in Custom Script Extension to execute shell command to pull script from Github and execute it in Bash using variables passed in from Powershell
#   - Logs in to Azure AD using the user managed identity string (passed through Bicep as a Bash variable)
#   - Pulls secrets from Azure Keyvault to use as passwords for MySQL and Letsencrypt registration info
#   - Installs Zabbix and MySQL server from repos
#   - Uses certbot to generate HTTPS certificate w/ auto renewal through Letsencrypt
#   - Sets up misc items like page file, time zone, cron jobs for backups and to handle reboots
#
#
# Defaults to a B1s instance with 1 CPU and 1G RAM
#
# This script assumes you have:
# - The SSH Key for console login pre-generated, with the public key stored in a separate resource group in the same subscription
# - A "zabbix" user managed identity created in in a separate resource group in the same subscription
# - An Azure Keyvault that:
#    - Is set for Azure RBAC access (under Settings -> Access Policies)
#    - Has the "zabbix" user managed identity assigned the Key Vault Secrets User role on the Keyvault (Access control IAM)
#    - Has 4 secrets pre-populated in the keyvault
#      - mysql-root-password
#      - mysql-zabbix-password
#      - letsencrypt-email
#      - letsencrypt-domain


#############
# Variables #
#############

# General Variables
$projectName = "zabbix"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$rgName = "rg-$projectName"

# VM Creation Variables
$vmName = "TA1-SV16-Zabbix"
$sshkeyRgName = "rg-keyvault"  ## Name of the resource group that you store your SSH keys in
$sshkeyName = "vmkey"          ## Name of the public SSH key you want to use for the VM
$managedidentityResourceGroup = "rg-usermanagedidentities"
$managedidentityName = "zabbix"

# VM Setup Script Variables (passed into Bash using Custom Script Extension)
$vmSetupScriptURL = "https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Zabbix/zabbixsetup-ubuntu2204.sh"
$vmTimeZone = "America/New_York"
$vmSwapFileSize = "1G"
$vmKeyVaultName = "keyvault-zabbix"

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
    -TemplateFile "./zabbixsetup.bicep" `
    -projectName $projectName `
    -projectLocation $projectLocation `
    -vmName $vmName `
    -sshpublickey $sshkey.publicKey `
    -vmSetupScriptURL $vmSetupScriptURL `
    -managedidentityID $managedidentityID.Id `
    -vmTimeZone $vmTimeZone `
    -vmSwapFileSize $vmSwapFileSize `
    -vmKeyVaultName $vmKeyVaultName