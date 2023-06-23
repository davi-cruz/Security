$tracefmt = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\tracefmt.exe'
$SymbolPath = 'srv*c:\Symbols*https://msdl.microsoft.com/download/symbols'
$outputLog = 'C:\Temp\'
$logName = 'WindowsUpdate'
$etlPath = 'C:\Temp\WindowsUpdate'

# Get ETLs
$arrETLs = Get-ChildItem -Path $etlPath -Filter '*.etl' | Sort-Object -Property LastWriteTime
[int]$ETLCount = $arrETLs.Count

# Break into batches of 15 (tracefmt limitation)
[single]$NumGroups = [math]::Ceiling($ETLCount/15)


[int]$intGrpCtr = 1
[int]$intETLCtr = 0
# Process Groups
while ($intGrpCtr -le $NumGroups) {
    New-Variable -Name "tmpVar$intGrpCtr"
    $tmpVar = Get-Variable -name "tmpVar$intGrpCtr"
    # Obtain 15 lines from batch
    while (($intETLCtr -lt (15 * $intGrpCtr)) -and ($intETLCtr -lt $ETLCount)) {
        $curETL = ($arrETLs[$intETLCtr]).Name
        $tmpVar.Value += "$CurETL "
        $intETLCtr++
    }

    Set-location $etlPath
    # Parse Logs
    [string]$strLogList = $tmpvar.Value
    Write-Output """$tracefmt"" -o ""$outputLog\$logName$intGrpCtr.log"" -r $SymbolPath $strLogList"
    $sbTrace = $ExecutionContext.InvokeCommand.NewScriptBlock("&""$tracefmt"" -o ""$outputLog\$logName$intGrpCtr.log"" -r $SymbolPath $strLogList")
    Invoke-Command -ScriptBlock $sbTrace

    # Cleanup
    Remove-Variable -name "tmpVar$intGrpCtr"
    $intGrpCtr++
    $tmpVar = $null
}

