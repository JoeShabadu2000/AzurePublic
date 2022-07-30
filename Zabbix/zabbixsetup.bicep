@description('Name of the project (passed through from Powershell script)')
param projectName string

@description('Location to use for the project (passed through from Powershell script)')
param projectLocation string

@description('Name of the Vnet')
param vnetName string = 'vnet-${projectName}'

@description('IP Address Range of the Vnet (CIDR)')
param vnetIPAddress string = '10.227.0.0/16'

@description('Name of the Subnet')
param subnetName string = 'subnet-${projectName}'

@description('IP Address Range of the Subnet (CIDR)')
param subnetIPAddress string = '10.227.1.0/24'

@description('Name to be used for the Virtual Machine')
param vmName string = 'vm-${projectName}'

@description('Name of the Public IP Address')
param publicipName string = 'publicip-${projectName}'

@description('SKU to use for the Public IP')
@allowed([
  'Basic'
  'Standard'
])
param publicipSKU string = 'Basic'

@description('FQDN for public IP (will concatenate [name].[region].cloudapp.azure.com)')
param publicIPFQDN string = 'tabula${projectName}'


// Create VNet and Subnet
// Uses Virtual Network module from public registry

module vnetBlock 'br/public:network/virtual-network:1.0.2' = {
  name: vnetName
  params: {
    name: vnetName
    location: projectLocation
    addressPrefixes: [
      vnetIPAddress
    ]
    subnets: [
      {
        name: subnetName
        addressPrefix: subnetIPAddress
      }
    ]
  }
}

// Deploy Public IP

resource publicipBlock 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: publicipName
  dependsOn: [
    vnetBlock
  ]
  location: projectLocation
  sku: {
    name: publicipSKU
  }
  properties: {
    dnsSettings: {
      fqdn: publicIPFQDN
    }
  }
}
