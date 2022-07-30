$subscriptionName="Microsoft Partner Network"
$rgName="rg-zabbixbasic"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob