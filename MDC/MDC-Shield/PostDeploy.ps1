[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$MainAppDisplayName,
    [Parameter(Mandatory = $true)][string]$ClientAppDisplayName, 
    [Parameter(Mandatory = $false)][string]$RoleName = "AssumeRoleWithWebIdentity"
)

function New-EntraIDAppRoleAssignment {
    param (
        [Parameter(Mandatory = $true)][string]$mainAppObject,
        [Parameter(Mandatory = $true)][string]$clientAppObject, 
        [Parameter(Mandatory = $true)][string]$roleObject
    )

    $body = @{
        principalId = $clientAppObject.id
        resourceId  = $mainAppObject.id
        appRoleId   = $roleObject.id
    } | ConvertTo-Json

    $header = @{
        'Authorization' = "Bearer $($token.Token)"
        'Content-Type'  = 'application/json'
    }

    Write-Verbose $body
    Write-Verbose "$graphUrl/v1.0/servicePrincipals/$($clientAppObject.id)/appRoleAssignments"
    Write-Verbose $header

    $results = Invoke-RestMethod -Method Post -Uri "$graphUrl/v1.0/servicePrincipals/$($clientAppObject.id)/appRoleAssignments" -Headers $header -Body $body -SkipHttpErrorCheck
    
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

    Write-Verbose "HEADER: $header"
    Write-Verbose "BODY: $body"
    Write-Verbose "URI: $graphUrl/v1.0/servicePrincipals$queryString"
    
    $results = Invoke-RestMethod -Method Get -Uri "$graphUrl/v1.0/servicePrincipals$queryString" -Headers $header
    
    # Get the app in case multiple apps with similar names exist
    foreach ($result in $results.value) {
        if ($result.displayName -eq $ClientAppDisplayName) {
            $app = $result
        }
    }

    return $app
}

if($Verbose){
    $VerbosePreference = "Continue"
}

## Variables
$graphUrl = "https://graph.microsoft.com"

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
$appRole = $mainAppObject.AppRoles | Where-Object { $_.DisplayName -eq $RoleName }

# Get the app in case multiple apps with similar names exist
foreach ($result in $results.value) {
    if ($result.displayName -eq $ClientAppDisplayName) {
        $clientApp = $result
    }
}

New-EntraIDAppRoleAssignment -mainAppObject $mainApp -clientAppObject $clientApp -roleObject $appRole