$subscriptionName="Microsoft Partner Network"
$rgName="rg-urbackup"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob