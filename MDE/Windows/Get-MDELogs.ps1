<#
.SYNOPSIS
    Collects MDE Computer Status and Preferences, as well as MDM Logs, in order to make it simple to review
    currently applied settings either manually or via MDM.
    Output file defaults to C:\Temp\MDESettings-<ComputerName>-<DateTime>.zip, but can be changed via the OutputFolder parameter.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "C:\Temp\MDESettings-$($env:COMPUTERNAME)-$(Get-Date -f "yyyyMMddHHmmss").zip"
)

$folder = $OutputFile.Replace(".zip", "")

# Prepare results folder (which will be later removed)
New-Item -Path $folder -ItemType Directory -Force | Out-Null

# Collect MDE Settings
$commands = @("Get-MpComputerStatus", "Get-MpPreference")

foreach ($command in $commands) {
    Invoke-Expression $command | Select-Object -ExcludeProperty CimClass, CimSystemProperties, CimInstanceProperties | ConvertTo-Json -Depth 5 | Out-File -FilePath "$folder\$command.json"
}

# Collect MDM Settings
&"C:\Windows\System32\MdmDiagnosticsTool.exe" -out "$folder"

# Compress results and save to output file
Compress-Archive -Path $folder -DestinationPath "$folder.zip"

# Cleanup temporary folder
Remove-Item -Path $folder -Recurse -Force