$projectName = "zabbixbasic"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$vmName = "TA1-SV16-Zabbix"

$rgName = "rg-$projectName"

# Set Correct Subscription
Set-AzContext $subscriptionName

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $projectLocation

# Deploy Script using variables listed above
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile "https://github.com/JoeShabadu2000/AzurePublic/blob/4db9de4c47d2a29f75fb08c24c0275db65b056a2/Zabbix/zabbixsetup.bicep" -projectName $projectName -projectLocation $projectLocation -vmName $vmName