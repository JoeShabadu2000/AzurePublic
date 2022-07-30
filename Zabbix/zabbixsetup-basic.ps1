$projectName = "zabbixbasic"
$projectLocation = "eastus"
$subscriptionName = "Microsoft Partner Network"

$rgName = "rg-$projectName"

# Set Correct Subscription
Set-AzContext $subscriptionName

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $projectLocation

# Deploy Script using variables listed above
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile "C:\Users\User\Documents\GitHub\AzurePublic\zabbixbasic.json" -projectName $projectName -projectLocation $projectLocation