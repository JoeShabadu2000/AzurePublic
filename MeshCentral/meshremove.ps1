$subscriptionName="Microsoft Partner Network"
$rgName="rg-mesh1"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob