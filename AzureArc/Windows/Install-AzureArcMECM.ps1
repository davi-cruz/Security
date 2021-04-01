#
# Script for deploying Azure Arc using an Automated Configuration Management Solution (Like Configuration Manager)
#
# Usage:
# - Change the variables in the header to match your requirements
# - Download the latest agent to your source content and put it in the same directory as this script


## Variables
$installLogFile = "c:\Windows\Temp\AzureArcSetup.log"

$tenantID = "TBD"
$subscriptionID = "TBD"
$ResourceGroupName = "TBD"
$serviceprincipalAppID = "TBD"
$serviceprincipalSecret = "TBD"
$resourceLocation = "TBD"
$proxyUrl = "" # Format: http[s]://server.fqdn:port

# Install Parameters
$installParam = @("/i", "AzureConnectedMachineAgent.msi" ,"/l*v", $installLogFile, "/qn")

if($proxyUrl -ne ""){
    Write-Output "Proxy specified. defining https_proxy as $proxyUrl"
    [Environment]::SetEnvironmentVariable("https_proxy", $proxyUrl, "Machine")
    $env:https_proxy = [System.Environment]::GetEnvironmentVariable("https_proxy","Machine")
}

# Install the package
$exitCode = (Start-Process -FilePath msiexec.exe -ArgumentList $installParam -Wait -Passthru).ExitCode
if($exitCode -ne 0) {
    $message=(net helpmsg $exitCode)
    Write-output "Installation failed: $message See $installLogFile for additional details."
    throw "Installation failed: $message See $installLogFile for additional details."
}

# Run connect command
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --tenant-id $tenantID `
    --subscription-id $subscriptionID `
    --resource-group $ResourceGroupName `
    --service-principal-id $serviceprincipalAppID `
    --service-principal-secret $serviceprincipalSecret `
    --location $resourceLocation `
    --cloud "AzureCloud"