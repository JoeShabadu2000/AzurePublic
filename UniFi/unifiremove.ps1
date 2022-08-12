$subscriptionName="Microsoft Partner Network"
$rgName="rg-unifi"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob