<#
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 

We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software
product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the
Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims
or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
#>
[CmdletBinding()]
param (
    [string]$BackupPath = "C:\Temp\BackupIntune\"
)

## Requer PowerShell 5, pre-requisito para o módulo Microsoft.Graph.Intune
$majorVersion = $PSVersionTable.PSVersion.Major
if($majorVersion -ne 5) {
    Write-Host "This script requires PowerShell 5. You have PowerShell $majorVersion"
    exit
}

$modules = @("IntuneBackupAndRestore", "Microsoft.Graph.Intune")
foreach($module in $modules) {
    ## Tenta atualizar módulo, se não existir, instala
    try{
        Update-module $module -force
    }
    catch{
        Install-Module $module -Scope CurrentUser -force
    }
}

## Conecta no Microsoft Graph
Connect-MSGraph

## Restaura o backup
## Ajustar o caminho do arquivo de backup
## Exemplo de estrutura utilizada:
## tree C:\Temp\BackupIntune
##├── BackupIntune
##│   └── Settings Catalog
##│       ├── MDE-PoC-Antivirus.json
##│       └── MDE-PoC-AttackSurfaceReductionRules.json

Invoke-IntuneRestoreConfigurationPolicy -Path $BackupPath -Verbose