# General Scripts

This folder contains several scripts for general use, but there are some of them that I've written to help me in my day-to-day work, described below:

## `Check-AzureIP.ps1`

This script was created to simplify identification of a Azure Service IP. It retrieves the latest JSON file from Microsoft and checks to which Services that specific IP is included.

### Sample usage

```bash
PS> ./Check-AzureIP -IPAddress 1.2.3.4
```

## `Configure MMA Agent.ps1`

This is an old script I've written to be used in a Configuration Manager Compliance Baseline, which evaluates and remediates MMA configurations.

As MMA is in deprecation process, I've decided to not update this script anymore, but I'm keeping it here for reference in case someone needs something similar.

## `Invoke-WindowsUpdateParsing.ps1`

This script uses `tracefmt.exe` to parse Windows Update logs from *.etl files. It's useful when you need to troubleshoot Windows Update issues but I believe it's not very useful nowadays, as native powershell cmdlets are available to do the same job. 

Again, another script I'm keeping here for reference in case someone needs something similar :smile:.

## `Update-Sysinternals.ps1`

I've created this script to download and/or update Sysinternals binaries in a specific system.
Note that Sysinternals App was released in Microsoft Store and can easily be installed and updated from there, but if you need just a few utilities, this is the way to go :smile:.
