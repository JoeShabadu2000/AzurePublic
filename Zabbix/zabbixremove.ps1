$subscriptionName="Microsoft Partner Network"
$rgName="rg-zabbix1"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force