Get-SmbShare -name "Exfil" | Remove-SmbShare
Remove-Item $PSScriptRoot\Temp -Recurse -Force