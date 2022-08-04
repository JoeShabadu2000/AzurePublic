$subscriptionName="Microsoft Partner Network"
$rgName="rg-elastic"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force