## https://learn.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2?view=exchange-ps
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$blockDomain    
)

$domainName = "MSDx123456.onmicrosoft.com"

## Prepare domain to be blocked, reverting protections in the URL
$blockDomain = $blockDomain.Replace("hxxps","https").Replace("[dot]",".")

## Get only the domain name
$domain = $blockDomain -replace '.*://|www\.|\?.*',''
$domain = $domain.replace("/","")

## Import necessary module
Import-Module -Name "ExchangeOnlineManagement"

## Connects to Exchange Online using Automation Account Managed Identity
Connect-ExchangeOnline -ManagedIdentity -Organization $domainName

## Include Domain in Tenant Block List
try{
    New-TenantAllowBlockListItems -ListType Url -Block -Entries $blockDomain
}
catch{
    Write-Host "Error connecting to Exchange Online: $_" -ForegroundColor Red
    exit
}