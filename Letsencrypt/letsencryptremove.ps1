$subscriptionName="Microsoft Partner Network"
$rgName="rg-letsencrypt"

Set-AzContext $subscriptionName
Get-AzResourceGroup -Name $rgName | Remove-AzResourceGroup -Force -AsJob