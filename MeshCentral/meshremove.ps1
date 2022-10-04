$subscriptionName="Microsoft Partner Network"
$rgName="rg-mesh3"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob