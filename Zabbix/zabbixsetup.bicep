// Script to deploy infrastructure in Azure to host Zabbix on a Linux VM 
//
// Sets up (in order):
// Vnet and Subnet
// Public IP
// Network Security Group
// NIC
// VM


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

@description('SKU to use for the VM hardware spec')
@allowed([
  'Standard_B1s'
  'Standard_B1ms'
  'Standard_B1ls'
])
param vmSKU string = 'Standard_B1s'

@description('Username of the Linux administrator')
param vmAdminUsername string = 'azureuser'

@description('SSH Public Key (passed in through Powershell')
param sshpublickey string

@description('VM Image Publisher Name')
param vmImagePublisherName string = 'Canonical'

@description('VM Image Offer Name')
param vmImageOffer string = '0001-com-ubuntu-server-jammy'

@description('VM Image SKU')
param vmImageSKU string = '22_04-lts-gen2'

@description('VM Image Version')
param vmImageVersion string = 'latest'

@description('Storage account type to use for the VM managed disk')
@allowed([
  'PremiumV2_LRS'
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Standard_LRS'
  'UltraSSD_LRS'
])
param vmManagedDiskType string = 'Premium_LRS'

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

//
// Create Virtual Machine
//

resource vmResource 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: projectLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSKU
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicResource.id
        }
      ]
    }
    osProfile: {
      adminUsername: vmAdminUsername
      computerName: vmName
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              keyData: sshpublickey
              path: '/home/${vmAdminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisherName
        offer: vmImageOffer
        sku: vmImageSKU
        version: vmImageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: vmManagedDiskType
        }
      }
    }
  }
}
