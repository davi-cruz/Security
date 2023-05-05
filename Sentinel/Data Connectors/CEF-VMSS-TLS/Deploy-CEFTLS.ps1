param(
    [Parameter(Mandatory)]$workspaceId,
    [Parameter(Mandatory)]$workspaceKey,
    [Parameter(Mandatory)]$keyVaultName,
    [Parameter(Mandatory)]$tlsSecretName,
    [Parameter(Mandatory)]$caSecretName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateSet('Ubuntu', 'RedHat')][string]$platform
)

Write-Output "[+] Parameters:"
Write-Output " - workspaceId = $workspaceId"
Write-Output " - workspaceKey = $workspaceKey"
Write-Output " - keyVaultName = $keyVaultName"
Write-Output " - tlsSecretName = $tlsSecretName"
Write-Output " - caSecretName = $caSecretName"
Write-Output " - platform = $platform"

switch ($platform) {
    'Ubuntu' {
        $cloudInit = Get-Content -Path ./cloudinit-tls-ub.yml
        $armTemplate = Get-Content -Raw ./CEF-VMSS-TLS-UB-Template.json
    }
}

# Gather information about KeyVault
$kvResourceId = Get-AzKeyVault -VaultName $keyVaultName | Select-Object -ExpandProperty ResourceId

# Gather information about KeyVault Secrets (Thumbprint, SecretId)
$tlsSecret = Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $tlsSecretName

# Get CA certificate content
$caSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -name $caSecretName -AsPlainText

# Replace placeholders in cloud-init file
$cloudInit = $cloudInit | Foreach-Object { $_ -replace "<cacertb64>", $caSecret }
$cloudInit = $cloudInit | Foreach-Object { $_ -replace "<workspaceid>", $workspaceId }
$cloudInit = $cloudInit | Foreach-Object { $_ -replace "<workspacekey>", $workspaceKey }
$cloudInit = $cloudInit | Foreach-Object { $_ -replace "<thumbprint>", $tlsSecret.Thumbprint }

$executionTime = Get-Date -Format "ddMMyyyHHmmss"
$cloudInitFile = "cloud-init-$executionTime.txt"
$armTemplateFile = "template-$executionTime.json"

# Save to file and convert to base64
$cloudInit | Out-File -Encoding utf8 -FilePath $cloudInitFile
$cloudInitB64 = [System.Convert]::ToBase64String((Get-Content -path $cloudInitFile -Encoding Byte))

# Replace placeholders in ARM Template file
$armTemplate = $armTemplate | Foreach-Object { $_ -replace "<kvResourceId>", $kvResourceId }
$armTemplate = $armTemplate | Foreach-Object { $_ -replace "<tlsCertUrl>", $tlsSecret.Id }
$armTemplate = $armTemplate | Foreach-Object { $_ -replace "<tlsSecretUrl>", $tlsSecret.SecretId }
$armTemplate = $armTemplate | Foreach-Object { $_ -replace "<cloudInitb64>", $cloudInitB64 }

$armTemplate | Out-File -Encoding utf8 -FilePath $armTemplateFile