[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName,

    [Parameter(Mandatory = $false)]
    [string]$packageUrl = 'https://github.com/davi-cruz/Security/raw/main/MDC/MDC-Shield/Func_MDC-Shield-AWS.zip',

    [Parameter(Mandatory = $true)]
    [string]$MainAppDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$ClientAppDisplayName = $FunctionAppName,

    [Parameter(Mandatory = $false)]
    [string]$RoleName = "AssumeRoleWithWebIdentity",

    [Parameter(Mandatory = $false)]
    [bool]$SkipFunctionDeploy = $false
)

## Variables
$graphUrl = "https://graph.microsoft.com"
$packageLocation = Join-Path -Path $PSScriptRoot -ChildPath $(Split-Path $packageUrl -Leaf)

## Functions
function New-EntraIDAppRoleAssignment {
    param (
        [Parameter(Mandatory = $true)]
        [string]$mainAppId,

        [Parameter(Mandatory = $true)]
        [string]$clientAppId,

        [Parameter(Mandatory = $true)]
        [string]$roleObjectId
    )

    $body = @{
        principalId = $clientAppId
        resourceId  = $mainAppId
        appRoleId   = $roleObjectId
    } | ConvertTo-Json

    $headers = @{
        'Authorization' = "Bearer $($msgraphToken.Token)"
        'Content-Type'  = 'application/json'
    }

    try {
        $results = Invoke-RestMethod -Method Post -Uri "$graphUrl/v1.0/servicePrincipals/$clientAppId/appRoleAssignments" -Headers $headers -Body $body -SkipHttpErrorCheck
        
        if ($results.error) {
            $response = @{
                'status'  = $results.error.code
                'message' = $results.error.message
            } | ConvertTo-Json
            return $response
        }
        else {
            return $results
        }
    }
    catch {
        throw "Error creating app role assignment: $($_.Exception.Message)"
    }
}

function Get-EntraIDServicePrincipal {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appDisplayName
    )

    $headers = @{
        'Authorization'    = "Bearer $($msgraphToken.Token)"
        'Content-Type'     = 'application/json'
        'ConsistencyLevel' = 'eventual'
    }

    $queryString = "?`$search=`"displayName:$appDisplayName`""
    $results = Invoke-RestMethod -Method Get -Uri "$graphUrl/v1.0/servicePrincipals$queryString" -Headers $headers
    
    # Get the app in case multiple apps with similar names exist
    foreach ($result in $results.value) {
        if ($result.appDisplayName -eq $appDisplayName) {
            return $result
        }
    }

    throw "Service principal with app display name '$appDisplayName' not found."
}

##===============
## Main Execution
##===============

## Get Access Tokens
try {
    $msgraphToken = Get-AzAccessToken -ResourceUrl $graphUrl
    $azureToken = Get-AzAccessToken
}
catch {
    throw "Error obtaining access token: $($_.Exception.Message)"
}

## Assign App Role
try {
    $mainApp = Get-EntraIDServicePrincipal -appDisplayName $MainAppDisplayName
    $clientApp = Get-EntraIDServicePrincipal -appDisplayName $ClientAppDisplayName
    $appRole = $mainApp.AppRoles | Where-Object { $_.DisplayName -eq $RoleName }

    New-EntraIDAppRoleAssignment -mainAppId $mainApp.id -clientAppId $clientApp.id -roleObjectId $appRole.id
}
catch {
    throw "Error while getting service principals or creating app role assignment: $($_.Exception.Message)"
}

## Publish Function App content
$scmHeader = @{
    "Authorization" = "Bearer $($azureToken.Token)"
    "Content-Type"  = "application/json"
}

$body = @{
    "packageUri" = $packageUrl
} | ConvertTo-Json

try {
    Write-Output "Starting deployment of package $packageUrl"
    $zipDeployUrl = "https://$FunctionAppName.scm.azurewebsites.net/api/zipdeploy?isAsync=true"
    Invoke-RestMethod -Method 'PUT' -Uri $zipDeployUrl -Headers $scmHeader -Body $body
    Start-Sleep -Seconds 15
}
catch {
    throw "Error deploying package. Please check the logs for more details."
}


if ($SkipFunctionDeploy -ne $true) {
    ## Get logs
    $logUrl = $null

    $latestDeploymentUrl = "https://$FunctionAppName.scm.azurewebsites.net/api/deployments/latest"
    $latestDeployment = Invoke-RestMethod -Method Get -Uri $latestDeploymentUrl -Headers $scmHeader | Select-Object -ExpandProperty id

    Write-Output "Deployment started. Waiting for deployment to complete..."

    while ($true) {
        $deploymentUrl = "https://$FunctionAppName.scm.azurewebsites.net/api/deployments/$latestDeployment"
        $deployment = Invoke-RestMethod -Method Get -Uri $deploymentUrl -Headers $scmHeader

        if ($null -ne $deployment.end_time) {
            break
        }

        Start-Sleep -Seconds 5
    }

    $logUrl = "https://$FunctionAppName.scm.azurewebsites.net/api/deployments/$latestDeployment/log"

    if ($logUrl) {
        Write-Output "Deployment logs: $deploymentUrl/log"
        $logs = Invoke-RestMethod -Method Get -Uri $logUrl -Headers $scmHeader
        $logs | ForEach-Object { Write-Output $_.message }
    }
}