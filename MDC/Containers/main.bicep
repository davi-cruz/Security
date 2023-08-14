@description('Name suffix for the resources')
param resourceName string

@description('The location of the Managed Cluster resource.')
param location string = resourceGroup().location

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize.')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@description('The number of nodes for the cluster.')
@minValue(1)
@maxValue(50)
param agentCount int = 1

@description('The size of the Virtual Machine.')
@allowed([
  'Standard_B2ms'
  'Standard_DS2_v2'
])
param agentVMSize string = 'Standard_B2ms'

@description('User name for the Linux Virtual Machines.')
param linuxAdminUsername string

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

var clusterName = 'aks-${resourceName}'
var acrString = replace('acr${resourceName}${uniqueString(resourceGroup().id)}', '-', '')
var acrName = length(acrString) > 50 ? substring(acrString, 0, 50) : acrString

resource aks 'Microsoft.ContainerService/managedClusters@2022-05-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
      }
    ]
    linuxProfile: {
      adminUsername: linuxAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshRSAPublicKey
          }
        ]
      }
    }
  }
}

resource acrResource 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
  }
}

resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acrResource.id, aks.identity.principalId)
  scope: acrResource.id
  properties: {
    principalId: aks.identity.principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${acrResource.resourceGroup}/providers/Microsoft.ContainerRegistry/registries/push'
  }
}

resource aksRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aks.id, acrResource.id)
  scope: aks.id
  properties: {
    principalId: acrResource.properties.adminUserAssignedIdentity.principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${acrResource.resourceGroup}/providers/Microsoft.ContainerRegistry/registries/pull'
  }
}

resource aksUpdate 'Microsoft.ContainerService/managedClusters@2022-05-02-preview' = {
  name: aks.name
  location: aks.location
  identity: aks.identity
  properties: {
    dnsPrefix: aks.properties.dnsPrefix
    agentPoolProfiles: aks.properties.agentPoolProfiles
    linuxProfile: aks.properties.linuxProfile
    servicePrincipalProfile: aks.properties.servicePrincipalProfile
    enablePodIdentity: aks.properties.enablePodIdentity
    podIdentityProfile: aks.properties.podIdentityProfile
    networkProfile: {
      networkPlugin: 'azure'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
      loadBalancerSku: 'standard'
    }
    addonProfiles: {
      aciConnectorLinux: {
        enabled: true
        config: {
          acrName: acrResource.name
        }
      }
    }
  }
}

output controlPlaneFQDN string = aks.properties.fqdn
output loginServer string = acrResource.properties.loginServer
