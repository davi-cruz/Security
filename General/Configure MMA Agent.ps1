#####################################
############# Configura Workspace
#####################################
#### Detection
$workspaceId = "<Your workspace Id>"
$mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$configuredWorkspaces = $mma.GetCloudWorkspaces() | Select-Object -ExpandProperty workspaceId
if($workspaceId -in $configuredWorkspaces){
    Write-Output "Compliant"
}
else{
    Write-Output "Not Compliant"
}

#### Remediation
$workspaceId = "<Your workspace Id>"
$workspaceKey = "<Your workspace Key>"
$mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$mma.AddCloudWorkspace($workspaceId, $workspaceKey)
$mma.ReloadConfiguration()

#####################################
############# Configura proxy
#####################################
#### Detection
$proxyUrl = "proxy.server.fqdn:8080" # não coloca http ou https
$mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
if($proxyUrl -eq $mma.proxyUrl()){
    Write-Output "Compliant"
}
else{
    Write-Output "Not-Compliant"
}

#### Remediation
$proxyUrl = "proxy.server.fqdn:8080" # não coloca http ou https
$mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$mma.SetProxyUrl($proxyUrl)
$mma.ReloadConfiguration()