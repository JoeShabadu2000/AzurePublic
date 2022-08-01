# General Variables
$projectName = "zabbix"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$rgName = "rg-$projectName"

# VM Creation Variables
$vmName = "TA1-SV16-Zabbix"
$sshkeyRgName = "rg-keyvault"  ## This is the name of the resource group that you store your SSH keys in
$sshkeyName = "vmkey"  ## This is the name of the public SSH key you want to use for the VM
$vmSetupScriptCommand = "wget -O - https://raw.githubusercontent.com/JoeShabadu2000/AzurePublic/main/Zabbix/zabbixsetup-ubuntu2204.sh | bash"
$managedidentityID = "/subscriptions/d8fb35c9-d357-4d07-a0f1-b694659e32e4/resourceGroups/rg-usermanagedidentities/providers/Microsoft.ManagedIdentity/userAssignedIdentities/zabbix"

# VM Environment Variables (passed into /etc/profile using Linux Custom Script Extension)
$vmTimeZone = "America/New_York"
$vmSwapFileSize = "1G"
$vmKeyVaultName = "keyvault-zabbix"

#############

# Set Correct Subscription
Set-AzContext $subscriptionName

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
    -vmSetupScriptCommand $vmSetupScriptCommand `
    -managedidentityID $managedidentityID `
    -vmTimeZone $vmTimeZone `
    -vmSwapFileSize $vmSwapFileSize `
    -vmKeyVaultName $vmKeyVaultName