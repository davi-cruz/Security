$uri = "https://<endpoint>/api/nextPageUrl"
$authHeader = @{
    "x-api-key" = "<API Key>"
}
$results = @()
$data = Invoke-RestMethod -method Get -uri $uri -Headers $authHeader
$results += $data.messages
while ($data.hasNext) {
    $data = Invoke-RestMethod -method Get -uri $data.nextLink -Headers $authHeader
    $results += $data.messages
}

$results | Format-List *