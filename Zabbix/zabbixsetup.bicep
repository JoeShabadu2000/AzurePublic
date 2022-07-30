//
// Define Parameters
//

// General Parameters
@description('Name of the project (passed through from Powershell script)')
param projectName string

@description('Location to use for the project (passed through from Powershell script)')
param projectLocation string

//Network Parameters
@description('Name of the Vnet')
param vnetName string = 'vnet-${projectName}'

@description('IP Address Range of the Vnet (CIDR)')
param vnetIPAddress string = '10.227.0.0/16'

@description('Name of the Subnet')
param subnetName string = 'subnet-${projectName}'

@description('IP Address Range of the Subnet (CIDR)')
param subnetIPAddress string = '10.227.1.0/24'

@description('Name of the Public IP Address')
param publicipName string = 'publicip-${projectName}'

@description('SKU to use for the Public IP')
@allowed([
  'Basic'
  'Standard'
])
param publicipSKU string = 'Basic'

@description('Domain name for public IP (will concatenate [name].[region].cloudapp.azure.com)')
param publicIPDomainName string = 'tabula${projectName}'

@description('Name of the Network Security Group')
param nsgName string = 'nsg-${projectName}'

@description('Name of the NIC to be used with the VM')
param nicName string = 'nic-${projectName}'

@description('Name of the NIC IP configuration')
param nicIPConfigName string = 'nicipconfig-${projectName}'

// VM Parameters
@description('Name to be used for the Virtual Machine')
param vmName string = 'vm-${projectName}'


//
// Create VNet and Subnet
//

// Uses Virtual Network module from public registry
module vnetResource 'br/public:network/virtual-network:1.0.2' = {
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

//
// Create Public IP
//

resource publicipResource 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: publicipName
  dependsOn: [
    vnetResource
  ]
  location: projectLocation
  sku: {
    name: publicipSKU
  }
  properties: {
    dnsSettings: {
      domainNameLabel: publicIPDomainName
    }
  }
}

//
// Deploy Network Security Group
//

// Load Standard NSG Rules (22,80,443) into variable
var nsgStandardRules = loadJsonContent('./nsgrules-standard.json', 'securityRules')

// Load Zabbix specific NSG rules (10050, 10051) into variable
var nsgCustomRules = loadJsonContent('./nsgrules-zabbix.json', 'securityRules')

// Create NSG
resource nsgResource 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: nsgName
  location: projectLocation
  properties: {
    securityRules: concat(nsgStandardRules, nsgCustomRules)
  }
}


//
// Create NIC, link with existing NSG and public IP
//

resource nicResource 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: nicName
  location: projectLocation
  properties: {
    networkSecurityGroup: {
      id: nsgResource.id
    }
    ipConfigurations: [
      {
        name: nicIPConfigName
        properties: {
          publicIPAddress: {
            id: publicipResource.id
          }
          subnet: {
            id: vnetResource.outputs.subnetResourceIds[0]
          }
        }
      }
    ]
  }
}
