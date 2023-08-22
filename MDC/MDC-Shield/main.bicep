@description('The name of the Azure Function app.')
param functionAppName string = 'func-${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Microsoft Entra ID App URI/URN.')
param AZURE_MSI_AUDIENCE string = 'urn://mdc_shield_aws/.default'

@description('The zip content url.')
param packageUri string = 'https://github.com/davi-cruz/Security/raw/main/MDC/MDC-Shield/Func_MDC-Shield-AWS.zip'

param utcValue string = utcNow()

var hostingPlanName = functionAppName
var applicationInsightsName = functionAppName
var storageAccountName = 'azfunctions${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: {
    'hidden-link:${resourceId('Microsoft.Web/sites', functionAppName)}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
  }
  kind: 'web'
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp,linux'
  properties: {
    reserved: true
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.10'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(resourceId('Microsoft.Insights/components', functionAppName), '2020-02-02').InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'AZURE_MSI_AUDIENCE'
          value: AZURE_MSI_AUDIENCE
        }
      ]
    }
  }
  dependsOn: [
    applicationInsight
  ]
}

resource enableBasicPublishingCreds 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-03-01' = {
  name: 'scm'
  kind: 'string'
  parent: functionApp
  properties: {
    allow: true
  }
}

var publishingCredentialsId = resourceId('Microsoft.Web/sites/config', functionApp.name, 'publishingCredentials')
var pubUser = list(publishingCredentialsId, '2022-03-01').properties.publishingUserName
var pubPass = list(publishingCredentialsId, '2022-03-01').properties.publishingPassword
var authString = base64('${pubUser}:${pubPass}')

output arguments string = '-a "${functionApp.name}" -b "${authString}" -c "${packageUri}"'

resource runPowerShellInlineWithOutput 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'runPowerShellInlineWithOutput'
  location: location
  kind: 'AzurePowerShell'
  dependsOn: [ enableBasicPublishingCreds ]
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '8.3'
    environmentVariables:[
      {
        name: 'functionName'
        value: functionApp.name
      }
      {
        name:'authString'
        secureValue: authString
      }
      {
        name: 'packageUri'
        value: packageUri
      }
    ]
    scriptContent: '''
      param(
        [string] $a = $env:functionName,
        [string] $b = $env:authString,
        [string] $c = $env:packageUri
      )
      
      function Write-LogMessage($message) {
          $DeploymentScriptOutputs['text'] = $deploymentScriptOutputs['text'] + "[$(Get-Date -f 'dd/MM/yyyy HH:mm:ss')] $message `n"
          Write-Output "[$(Get-Date -f 'dd/MM/yyyy HH:mm:ss')] $message `n"
      }
        
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs['text'] = ""
      $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
      $headers.Add("Content-Type", "application/json")
      $headers.Add("Authorization", "Basic $b")
        
      $body = @{
          "packageUri" = $c
      } | ConvertTo-Json -Compress
        
      ## Post to Kudu API to deploy the zip file in Github
      Invoke-RestMethod "https://$a.scm.azurewebsites.net/api/zipdeploy?isAsync=true" -Method 'PUT' -Headers $headers -Body $body -ResponseHeadersVariable responseHeaders
      Write-LogMessage -message "Deployment started. Waiting for deployment to complete..."
      Start-Sleep 10
        
      ## Get the latest deployment ID
      $latestDeploymentUrl = $responseHeaders['Location'][0]
      $latestDeployment = Invoke-RestMethod -Method Get -Uri $latestDeploymentUrl -Headers $headers | Select-Object -ExpandProperty id
        
      ## Loop until the deployment is complete
      while ($true) {
          $deploymentUrl = "https://$a.scm.azurewebsites.net/api/deployments/$latestDeployment"
          $deployment = Invoke-RestMethod -Method Get -Uri $deploymentUrl -Headers $headers
        
          if ($null -ne $deployment.end_time) {
              break
          }
        
          Start-Sleep -Seconds 5
      }
        
      ## Get Deployment logs
      $logUrl = "https://$a.scm.azurewebsites.net/api/deployments/$latestDeployment/log"
      if ($logUrl) {
          Write-LogMessage -message  "Deployment logs: $deploymentUrl/log"
          $logs = Invoke-RestMethod -Method Get -Uri $logUrl -Headers $headers
          $logs | ForEach-Object { Write-LogMessage -message  $_.message }
      }
    '''
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}
