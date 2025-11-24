// ============================================================================
// Bielik VM Deployment - Main Bicep Template
// Automatyczny deployment Bielik + Ollama na Azure VM
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Nazwa maszyny wirtualnej')
param vmName string = 'bielik-vm'

@description('Rozmiar VM (zalecane: Standard_D8s_v3 lub Standard_NC24ads_A100_v4 z GPU A100)')
@allowed([
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_D16s_v3'
  'Standard_NC6s_v3'
  'Standard_NC4as_T4_v3'
  'Standard_NC8as_T4_v3'
  'Standard_NC24ads_A100_v4'
  'Standard_NC48ads_A100_v4'
  'Standard_NC96ads_A100_v4'
])
param vmSize string = 'Standard_D8s_v3'

@description('Nazwa użytkownika administratora')
param adminUsername string = 'azureuser'

@description('Typ uwierzytelniania: password lub sshPublicKey')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Hasło administratora (wymagane gdy authenticationType = password)')
@secure()
param adminPassword string = ''

@description('Klucz publiczny SSH (wymagany gdy authenticationType = sshPublicKey)')
@secure()
param sshPublicKey string = ''

@description('Lokalizacja zasobów')
param location string = resourceGroup().location

@description('Model Bielik do pobrania w Ollama')
param bielikModel string = 'SpeakLeash/bielik-11b-v2.6-instruct'

@description('Czy otworzyć port Ollama API (11434) publicznie')
param enablePublicOllamaAccess bool = false

@description('Prefiks dla zasobów')
param resourcePrefix string = 'bielik'

@description('Tagi dla zasobów')
param tags object = {
  Environment: 'Development'
  Project: 'Bielik-Ollama'
  ManagedBy: 'Bicep'
}

// ============================================================================
// VARIABLES
// ============================================================================

var networkSecurityGroupName = '${resourcePrefix}-nsg'
var virtualNetworkName = '${resourcePrefix}-vnet'
var subnetName = '${resourcePrefix}-subnet'
var publicIPAddressName = '${resourcePrefix}-pip'
var networkInterfaceName = '${resourcePrefix}-nic'
var osDiskName = '${vmName}-osdisk'

// ============================================================================
// RESOURCES
// ============================================================================

// Network Security Group
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Ollama-API'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: enablePublicOllamaAccess ? 'Allow' : 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '11434'
        }
      }
      {
        name: 'HTTP'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
    ]
  }
}

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

// Public IP Address
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIPAddressName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${vmName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Network Interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: networkInterfaceName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

// Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: authenticationType == 'password' ? adminPassword : null
      linuxConfiguration: authenticationType == 'sshPublicKey' ? {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      } : {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

// Custom Script Extension - Instalacja Ollama i Bielik
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'installOllamaBielik'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: false
    }
    protectedSettings: {
      script: base64(replace(replace(loadTextContent('../scripts/install-ollama-bielik.sh'), '__ADMIN_USER__', adminUsername), '__BIELIK_MODEL__', bielikModel))
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Publiczny adres IP VM')
output publicIP string = publicIPAddress.properties.ipAddress

@description('FQDN VM')
output fqdn string = publicIPAddress.properties.dnsSettings.fqdn

@description('Komenda SSH do połączenia')
output sshCommand string = 'ssh ${adminUsername}@${publicIPAddress.properties.ipAddress}'

@description('URL Ollama API')
output ollamaApiUrl string = 'http://${publicIPAddress.properties.ipAddress}:11434'

@description('Zainstalowany model')
output installedModel string = bielikModel

@description('Nazwa VM')
output vmName string = virtualMachine.name

@description('Resource ID VM')
output vmResourceId string = virtualMachine.id
