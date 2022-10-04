$subscriptionName="Microsoft Partner Network"
$rgName="rg-mesh"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob