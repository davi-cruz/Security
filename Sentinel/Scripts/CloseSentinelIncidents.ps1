function Close-SentinelIncident($incident) {

    $properties = $incident.properties
    $values = @{
        status = "Closed"
        classification = "FalsePositive"
        classificationReason = "IncorrectAlertLogic"
        classificationComment = "Incorrect alert rule logic"
    }

    foreach($key in $values.Keys){
        try{
            $properties[$key] = $values[$key]
        }
        catch{
            $properties | Add-Member -NotePropertyName $key -NotePropertyValue $values[$key] -Force
        }
    }

    $incident.properties = $properties
    $requestBody = $incident | ConvertTo-Json -Depth 10
    
    Invoke-RestMethod -Uri "https://management.azure.com$($incident.id)?$apiVersion" `
        -Method Put -Body $requestBody -Headers $global:headers -verbose
}

function Get-SentinelIncidents ($uri) {
    $response = Invoke-RestMethod $uri -Method 'GET' -Headers $headers
    return $response
}

Import-module Az.Accounts
Connect-AzAccount

$Token = (Get-AzAccessToken).Token

$global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$global:headers.Add("Authorization", "Bearer $token")
$global:headers.Add("Content-Type", "application/json; charset=utf-8")

$subscriptionId = "2b6e5fa6-xxxxxx"
$resourceGroupName = "rg-dc-security"
$sentinelWorkspaceName = "log-security"
$apiVersion = "api-version=2020-01-01"
$filter = "properties/status ne 'Closed' and properties/title eq '<Name of alert here>'"


$initialUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$sentinelWorkspaceName/providers/Microsoft.SecurityInsights/incidents?$apiVersion&`$filter=$filter"
$global:actualUri = $initialUri

$results = Get-SentinelIncidents -uri $global:actualUri 

foreach ($result in $results.value) {
    Close-SentinelIncident -incident $result
}

while ($null -ne $results.nextLink) {
    $results = Get-SentinelIncidents -uri $global:actualUri 
    $global:actualUri = $results.nextLink

    foreach ($result in $results.value) {
        Close-SentinelIncident -incident $result
    }
}