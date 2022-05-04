#Requires -Version 5
<#
        .SYNOPSIS
        Grants Managed Identity permissions to Microsoft Graph API.

        .DESCRIPTION
        Grants Managed Identity permissions to Microsoft Graph API.

        .PARAMETER TenantID
        Azure AD Tenant ID.

        .PARAMETER DisplayNameOfMSI
        Name of Managed Identity Object.
        For System-assigned objects, use the resource name (eg. Logic App Name).
        For User-assigned objects, use the identity name.

        .INPUTS
        None. You cannot pipe objects to this function

        .OUTPUTS
        None

        .EXAMPLE
        PS> Grant-MSIGraphPermissions -TenantID "5b85b0e3-db24-4f17-9f4e-da32997cbe26" -DisplayNameOfMSI "id-ManagedIdentity" -Permissions @("User.ReadWrite.All","Directory.ReadWrite.All")
    #>

Param(
    [Parameter(Mandatory = $true)] $TenantID, 
    [Parameter(Mandatory = $true)] $DisplayNameOfMSI, 
    [Parameter(Mandatory = $true)] $Permissions
)

$GraphAppId = "00000003-0000-0000-c000-000000000000"

# Install the module
Install-Module AzureAD -Scope CurrentUser

Connect-AzureAD -TenantId $TenantID
$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'")
Start-Sleep -Seconds 10

$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"

foreach ($PermissionName in $Permissions) {
    $AppRole = $GraphServicePrincipal.AppRoles | `
        Where-Object { $_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application" }

    New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId `
        -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
}

# List current permissions for specified user

Get-AzureADServiceAppRoleAssignment -ObjectId $GraphServicePrincipal.ObjectId | `
    Where-Object { $_.PrincipalDisplayName -eq $DisplayNameOfMSI} | `
    Select-Object objectID, PrincipalDisplayName, PrincipalType