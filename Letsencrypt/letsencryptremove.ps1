$subscriptionName="Microsoft Partner Network"
$rgName="rg-letsencrypt2"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob