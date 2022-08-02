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

#############

# Set Correct Subscription
Set-AzContext $subscriptionName

# Get Managed Identity ID

$managedidentityID = Get-AzUserAssignedIdentity -Name $managedidentityName -ResourceGroupName $managedidentityResourceGroup

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $projectLocation

# Get SSH Public Key from Existing Resource Group, to use when setting up VM
$sshkey = Get-AzSshKey -ResourceGroupName $sshkeyRgName -Name $sshkeyName

# Deploy Script using variables listed above
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