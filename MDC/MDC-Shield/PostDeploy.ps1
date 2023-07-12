[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$FunctionAppName,
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$SubscriptionId,   
    [Parameter(Mandatory = $true)][string]$MainAppDisplayName,
    [Parameter(Mandatory = $true)][string]$ClientAppDisplayName,
    [Parameter(Mandatory = $false)][string]$RoleName = "AssumeRoleWithWebIdentity"
)

## Variables
$packageUrl = 'https://github.com/davi-cruz/Security/raw/main/MDC/MDC-Shield/Func_MDC-Shield-AWS.zip'
$graphUrl = "https://graph.microsoft.com"

function New-EntraIDAppRoleAssignment {
    param (
        [Parameter(Mandatory = $true)][string]$mainAppId,
        [Parameter(Mandatory = $true)][string]$clientAppId, 
        [Parameter(Mandatory = $true)][string]$roleObjectId
    )

    $body = @{
        principalId = $clientAppId
        resourceId  = $mainAppId
        appRoleId   = $roleObjectId
    } | ConvertTo-Json

    $header = @{
        'Authorization' = "Bearer $($token.Token)"
        'Content-Type'  = 'application/json'
    }

    Write-Verbose "HEADER: $($header | ConvertTo-Json)"
    Write-Verbose "QUERY: $graphUrl/v1.0/servicePrincipals/$clientAppId/appRoleAssignments"
    Write-Verbose "BODY: $body"

    $results = Invoke-RestMethod -Method Post -Uri "$graphUrl/v1.0/servicePrincipals/$clientAppId/appRoleAssignments" -Headers $header -Body $body -SkipHttpErrorCheck
    
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
function Get-EntraIDServicePrincipal {
    param (
        [Parameter(Mandatory = $true)][string]$appDisplayName
    )

    $header = @{
        'Authorization'    = "Bearer $($token.Token)"
        'Content-Type'     = 'application/json'
        'ConsistencyLevel' = 'eventual'
    }

    $queryString = "?`$search=`"displayName:$appDisplayName`""

    Write-Verbose "URI: $graphUrl/v1.0/servicePrincipals$queryString"
    
    $results = Invoke-RestMethod -Method Get -Uri "$graphUrl/v1.0/servicePrincipals$queryString" -Headers $header
    
    
    # Get the app in case multiple apps with similar names exist
    foreach ($result in $results.value) {
        if ($result.appDisplayName -eq $appDisplayName) {
            $app = $result
        }
    }

    return $app
}

if($Verbose){
    $VerbosePreference = "Continue"
}

## Set Azure Subscription Context
try{
    Set-AzContext -SubscriptionId $SubscriptionId
}
catch{
    Write-Output "Error setting subscription"
    Exit 1
}

## Obtain Access Token from Azure session
$token = Get-AzAccessToken -ResourceUrl $graphUrl

## Get details from resources
$header = @{
    'Authorization'    = "Bearer $($token.Token)"
    'ConsistencyLevel' = 'eventual'
    'Content-Type'     = 'application/json'
}

## Get the Main App
$mainApp = Get-EntraIDServicePrincipal -appDisplayName $MainAppDisplayName
$clientApp = Get-EntraIDServicePrincipal -appDisplayName $ClientAppDisplayName
$appRole = $mainApp.AppRoles | Where-Object { $_.DisplayName -eq $RoleName }
# Get the app in case multiple apps with similar names exist
foreach ($result in $results.value) {
    if ($result.displayName -eq $ClientAppDisplayName) {
        $clientApp = $result
    }
}

Write-Verbose "Main App Id: $($mainApp.id)"
Write-Verbose "Client App: $($clientApp.id)"
Write-Verbose "App Role: $($appRole.id)"

New-EntraIDAppRoleAssignment -mainAppId $mainApp.id -clientAppId $clientApp.id -roleObjectId $appRole.id

## Deploy the Function Package
if($null -ne $IsLinux -and $IsLinux -eq $true){
    $workingDir = "/tmp"
}
else {
    $workingDir = $env:TEMP
}

$packageLocation = Join-Path -Path $workingDir -ChildPath "Func_MDC-Shield-AWS.zip"
Invoke-RestMethod -Method Get -Uri $packageUrl -OutFile $packageLocation

try {
    Publish-AzWebapp -ResourceGroupName $ResourceGroup -Name $FunctionAppName -ArchivePath $packageLocation
}
catch {
    <#Do this if a terminating exception happens#>
}