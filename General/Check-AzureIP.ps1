param(
    [string]$IPAddress = $null
)

try{
    [System.Net.IPAddress]$objIPAddress = $IPAddress
}
catch{
    Write-Output "Please inform a valid IP Address"
    exit
}

$url = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"
$TagsLink = (Invoke-WebRequest -Uri $url).Links.href | Where-Object {$_ -like '*.json'} | Select-Object -Unique
if(!($TagsLink -like '*json*')){
    Write-Output "[-] Azure Tags File not found. Aborting"
    exit
}

Write-Output "[+] Obtained Azure Service Tags address:"
Write-Output "    - $TargetLink"
$ServiceTags = (Invoke-RestMethod -Method Get -Uri $TagsLink).values
$notFound = $true

foreach($tag in $ServiceTags){
    $CIDRs = $tag.properties.addressPrefixes | Where-Object {$_ -notlike '*:*'}
    foreach($CIDR in $CIDRs){
        [IPAddress]$Subnet = ($CIDR -split '\\|\/')[0]
        [int]$PrefixLength = ($CIDR -split '\\|\/')[1]
        [IPAddress]$SubnetMask = [IPAddress]([string](4gb-([System.Math]::Pow(2,(32-$PrefixLength)))))

        if($Subnet.Address -eq ($objIPAddress.Address -band $SubnetMask.Address)){
            Write-Output "[+] Found IP $IPAddress in $CIDR - $($tag.name) [$($tag.Id)]"
            $notFound = $false
        }
    }
}

if($notFound){
    Write-Output "[-] IP $IPAddress not found in Azure Service Tags"
}