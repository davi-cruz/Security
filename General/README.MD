# General Scripts

Some information about the content available at this directory:

## `Check-AzureIP.ps1`

This script was created to simplify identification of a Azure Service IP. It retrieves the latest JSON file from Microsoft and checks to which Services that specific IP is included.

### Sample usage

```bash
PS> ./Check-AzureIP -IPAddress 1.2.3.4

```

## `Update-Sysinternals.ps1`

I've created this script to download and/or update Sysinternals binaries in a specific system.
Note that Sysinternals App was released in Microsoft Store and can easily be installed and updated from there, but if you need just a few utilities, this is the way to go :smile:.
