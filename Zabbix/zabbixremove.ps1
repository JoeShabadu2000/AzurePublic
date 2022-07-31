$subscriptionName="Microsoft Partner Network"
$rgName="rg-zabbix"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force