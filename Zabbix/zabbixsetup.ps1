$projectName = "zabbix"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"
$vmName = "TA1-SV16-Zabbix"

$rgName = "rg-$projectName"

# Set Correct Subscription
Set-AzContext $subscriptionName

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $projectLocation

# Deploy Script using variables listed above
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile "./zabbixsetup.bicep" -projectName $projectName -projectLocation $projectLocation -vmName $vmName