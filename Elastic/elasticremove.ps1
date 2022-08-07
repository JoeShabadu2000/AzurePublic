$subscriptionName="Microsoft Partner Network"
$rgName="rg-elastic1"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob