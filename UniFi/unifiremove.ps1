$subscriptionName="Microsoft Partner Network"
$rgName="rg-unifi1"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob