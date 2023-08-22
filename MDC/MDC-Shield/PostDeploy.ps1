[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName,

    [Parameter(Mandatory = $true)]
    [string]$MainAppDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$ClientAppDisplayName = $FunctionAppName,

    [Parameter(Mandatory = $false)]
    [string]$RoleName = "AssumeRoleWithWebIdentity"
)

## Variables
$graphUrl = "https://graph.microsoft.com"

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
        if ($result.displayName -eq $appDisplayName) {
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