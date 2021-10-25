# This script is no longer required once Sysinternals can now be installed from MSStore and winget on Windows 11 
# Feel free to use anyway :)

$uri = 'https://live.sysinternals.com'
$global:currentDirectory = Split-Path -Path $MyInvocation.MyCommand.path -parent
$toolsToInclude = @()
$toolsToExclude = @()

function Get-UpdatedVersion($file) {
  Write-host "[ ] Checking file $file" -ForegroundColor Cyan
  $liveFileContentLength = (Invoke-WebRequest -Method head -uri "$uri/$file" | select-object -ExpandProperty Headers)["Content-Length"]
  try { $currentFileContentLenght = Get-ItemProperty -Path "$global:currentDirectory\$file" | select-object -ExpandProperty Length -ErrorAction SilentlyContinue -Verbose }
  catch { $currentFileContentLenght = 0 }
  if ($liveFileContentLength -ne $currentFileContentLenght) {
    Write-host "  [+] Downloading latest version of $file" -ForegroundColor Green
    Invoke-WebRequest -Uri "$uri/$file" -OutFile "$global:currentDirectory\$file"
  }
}

$availableFiles = Invoke-WebRequest -Uri $uri
if ($toolsToInclude.Count -and -not($toolsToExclude)) {
  # Download only the files in list
  foreach ($file in $toolsToInclude) {
    Get-UpdatedVersion($file)
  } 
}
else {
  # Download all files, except the ones in the list to be excluded
  foreach ($link in $availableFiles.Links) {
    $file = ($link.HREF).Replace("/", "")
    if ($file -notin $toolsToExclude -and $file -like "*.exe") {
      Get-UpdatedVersion($file)
    }
  }
}