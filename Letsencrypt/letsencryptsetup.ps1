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
    -sslCertName $sslCertName