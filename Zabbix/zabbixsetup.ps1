# General Variables
$projectName = "zabbix"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$rgName = "rg-$projectName"

# VM Variables
$vmName = "TA1-SV16-Zabbix"
$sshkeyRgName = "keyvault"  ## This is the name of the resource group that you store your keys in
$sshkeyName = "vmkey"  ## This is the name of the public SSH key you want to use for the VM
$vmSetupScriptURI = "https://github.com/JoeShabadu2000/AzurePublic/blob/6b9d8e3d9c0ae134c60f4504dab2f4ac51efd494/Zabbix/zabbixsetup-ubuntu2204.sh"

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
    -vmSetupScriptURI $vmSetupScriptURI