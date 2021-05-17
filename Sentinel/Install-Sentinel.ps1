#requires -module @{ModuleName = 'Az.Accounts'; ModuleVersion = '1.5.2'}
#requires -version 6.2

# Script from Wortell AzSentinel
# Modified in order to support resource tag while
# enabling Azure Sentinel Solution


<#
    .SYNOPSIS
    Enable Azure Sentinel
    .DESCRIPTION
    This function enables Azure Sentinel on a existing Workspace
    .PARAMETER SubscriptionId
    Enter the subscription ID, if no subscription ID is provided then current AZContext subscription will be used
    .PARAMETER WorkspaceName
    Enter the Workspace name
    .EXAMPLE
    Set-AzSentinel -WorkspaceName ""
    This example will enable Azure Sentinel for the provided workspace
    #>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory = $false,
        ParameterSetName = "Sub")]
    [ValidateNotNullOrEmpty()]
    [string] $SubscriptionId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName, 

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Ambiente, 

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Servico, 

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Responsavel

)
begin
{
    function Get-LogAnalyticWorkspace
    {
        <#
        .SYNOPSIS
        Get log analytic workspace
        .DESCRIPTION
        This function is used by other function for getting the workspace infiormation and seting the right values for $script:workspace and $script:baseUri
        .PARAMETER SubscriptionId
        Enter the subscription ID, if no subscription ID is provided then current AZContext subscription will be used
        .PARAMETER WorkspaceName
        Enter the Workspace name
        .PARAMETER FullObject
        If you want to return the full object data
        .EXAMPLE
        Get-LogAnalyticWorkspace -WorkspaceName ""
        This example will get the Workspace and set workspace and baseuri param on Script scope level
        .EXAMPLE
        Get-LogAnalyticWorkspace -WorkspaceName "" -FullObject
        This example will get the Workspace ands return the full data object
        .EXAMPLE
        Get-LogAnalyticWorkspace -SubscriptionId "" -WorkspaceName ""
        This example will get the workspace info from another subscrion than your "Azcontext" subscription
        .NOTES
        NAME: Get-LogAnalyticWorkspace
        #>
        param (
            [Parameter(Mandatory = $false)]
            [ValidateNotNullOrEmpty()]
            [string] $SubscriptionId,
    
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$WorkspaceName,
    
            [Parameter(Mandatory = $false)]
            [ValidateNotNullOrEmpty()]
            [Switch]$FullObject
        )
    
        begin
        {
            precheck
        }
    
        process
        {
            if ($SubscriptionId)
            {
                Write-Verbose "Getting Worspace from Subscription $($subscriptionId)"
                $uri = "https://management.azure.com/subscriptions/$($subscriptionId)/providers/Microsoft.OperationalInsights/workspaces?api-version=2015-11-01-preview"
            } elseif ($script:subscriptionId)
            {
                Write-Verbose "Getting Worspace from Subscription $($script:subscriptionId)"
                $uri = "https://management.azure.com/subscriptions/$($script:subscriptionId)/providers/Microsoft.OperationalInsights/workspaces?api-version=2015-11-01-preview"
            } else
            {
                Write-Error "No SubscriptionID provided" -ErrorAction Stop
            }
    
            try
            {
                $workspaces = Invoke-webrequest -Uri $uri -Method get -Headers $script:authHeader -ErrorAction Stop
                $workspaceObject = ($workspaces.Content | ConvertFrom-Json).value | Where-Object { $_.name -eq $WorkspaceName }
            } catch
            {
                Write-Error $_.Exception.Message
                break
            }
    
            if ($workspaceObject)
            {
                $Script:workspace = ($workspaceObject.id).trim()
                $script:workspaceId = $workspaceObject.properties.customerId
                Write-Verbose "Workspace is: $($Script:workspace)"
                $script:baseUri = "https://management.azure.com$($Script:workspace)"
                if ($FullObject)
                {
                    return $workspaceObject
                }
                Write-Verbose ($workspaceObject | Format-List | Format-Table | Out-String)
                Write-Verbose "Found Workspace $WorkspaceName in RG $($workspaceObject.id.Split('/')[4])"
            } else
            {
                Write-Error "Unable to find workspace $WorkspaceName under Subscription Id: $($script:subscriptionId)"
            }
        }
    }

    function Get-AuthToken
    {
        <#
        .SYNOPSIS
        Get Authorization Token
        .DESCRIPTION
        This function is used to generate the Authtoken for API Calls
        .EXAMPLE
        Get-AuthToken
        #>
    
        [CmdletBinding()]
        param (
        )
    
        $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    
        Write-Verbose -Message "Using Subscription: $($azProfile.DefaultContext.Subscription.Name) from tenant $($azProfile.DefaultContext.Tenant.Id)"
    
        $script:subscriptionId = $azProfile.DefaultContext.Subscription.Id
        $script:tenantId = $azProfile.DefaultContext.Tenant.Id
    
        $profileClient = [Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient]::new($azProfile)
        $script:accessToken = $profileClient.AcquireAccessToken($script:tenantId)
    
        $script:authHeader = @{
            'Content-Type' = 'application/json'
            Authorization  = 'Bearer ' + $script:accessToken.AccessToken
        }
    
    }

    function precheck
    {
        $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
      
        if ($azProfile.Contexts.Count -ne 0)
        {
            if ($null -eq $script:accessToken )
            {
                Get-AuthToken
            } elseif ($script:accessToken.ExpiresOn.DateTime - [datetime]::UtcNow.AddMinutes(-5) -le 0)
            {
                # if token expires within 5 minutes, request a new one
                Get-AuthToken
            }
      
            # Set the subscription from AzContext
            $script:subscriptionId = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext.Subscription.Id
        } else
        {
            Write-Error 'No subscription available, Please use Connect-AzAccount to login and select the right subscription'
            break
        }
    }

    function Set-AzSentinelResourceProvider {
        <#
        .SYNOPSIS
        Set AzSentinelResourceProvider
        .DESCRIPTION
        This function is enables the required Resource providers
        .PARAMETER NameSpace
        Enter the name of the namespace without 'Microsoft.'
        .EXAMPLE
        Set-AzSentinelResourceProvider -NameSpace 'OperationsManagementOperationsManagement'
        #>
    
        [OutputType([String])]
        param (
            [string]$NameSpace
        )
    
        $uri = "https://management.azure.com/subscriptions/$($script:subscriptionId)/providers/Microsoft.$($NameSpace)/register?api-version=2019-10-01"
    
        try {
            $invokeReturn = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:authHeader
            Write-Verbose $invokeReturn
            do {
                $resourceProviderStatus = Get-AzSentinelResourceProvider -NameSpace $NameSpace
            }
            until ($resourceProviderStatus.registrationState -eq 'Registered')
            $return = "Successfully enabled Microsoft.$($NameSpace) on subscription $($script:subscriptionId). Status:$($resourceProviderStatus.registrationState)"
            return $return
        }
        catch {
            $return = $_.Exception.Message
            Write-Error $return
            return $return
        }
    }

    function Get-AzSentinelResourceProvider {
        <#
        .SYNOPSIS
        Get AzSentinelResourceProvider
        .DESCRIPTION
        This function is used to get status of the required resource providers
        .PARAMETER NameSpace
        Enter the name of the namespace without 'Microsoft.'
        .EXAMPLE
        Get-AzSentinelResourceProvider -NameSpace 'OperationsManagement'
        #>
        param (
            [string]$NameSpace
        )
    
        $uri = "https://management.azure.com/subscriptions/$($script:subscriptionId)/providers/Microsoft.$($NameSpace)?api-version=2019-10-01"
    
        try {
            $invokeReturn = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:authHeader
            return $invokeReturn
        }
        catch {
            $return = $_.Exception.Message
            Write-Error $return
            return $return
        }
    }

    precheck
}

process
{
    switch ($PsCmdlet.ParameterSetName)
    {
        Sub
        {
            $arguments = @{
                WorkspaceName  = $WorkspaceName
                SubscriptionId = $SubscriptionId
            }
        }
        default
        {
            $arguments = @{
                WorkspaceName = $WorkspaceName
            }
        }
    }

    try
    {
        $workspaceResult = Get-LogAnalyticWorkspace @arguments -FullObject -ErrorAction Stop
    } catch
    {
        Write-Error $_.Exception.Message
        break
    }

    # Variables
    $errorResult = ''

    if ($workspaceResult.properties.provisioningState -eq 'Succeeded')
    {

        <#
            Testing to see if OperationsManagement resource provider is enabled on subscription
            #>
        $operationsManagementProvider = Get-AzSentinelResourceProvider -NameSpace "OperationsManagement"
        if ($operationsManagementProvider.registrationState -ne 'Registered')
        {
            Write-Warning "Resource provider 'Microsoft.OperationsManagement' is not registered"

            if ($PSCmdlet.ShouldProcess("Do you want to enable 'Microsoft.OperationsManagement' on subscription $($script:subscriptionId)"))
            {
                Set-AzSentinelResourceProvider -NameSpace 'OperationsManagement'
            } else
            {
                Write-Output "No change have been."
                break
            }
        }

        <#
            Testing to see if SecurityInsights resource provider is enabled on subscription
            #>
        $securityInsightsProvider = Get-AzSentinelResourceProvider -NameSpace 'SecurityInsights'
        if ($securityInsightsProvider.registrationState -ne 'Registered')
        {
            Write-Warning "Resource provider 'Microsoft.SecurityInsights' is not registered"

            if ($PSCmdlet.ShouldProcess("Do you want to enable 'Microsoft.SecurityInsights' on subscription $($script:subscriptionId)"))
            {
                Set-AzSentinelResourceProvider -NameSpace 'SecurityInsights'
            } else
            {
                Write-Output "No change have been."
                break
            }
        }

        $body = @{
            'id'         = ''
            'etag'       = ''
            'name'       = ''
            'type'       = ''
            'location'   = $workspaceResult.location
            'properties' = @{
                'workspaceResourceId' = $workspaceResult.id
            }
            'plan'       = @{
                'name'          = 'SecurityInsights($workspace)'
                'publisher'     = 'Microsoft'
                'product'       = 'OMSGallery/SecurityInsights'
                'promotionCode' = ''
            }
            'tags' = @{
                'Responsavel' = $Responsavel
                'Ambiente' = $Ambiente
                'Servico' = $Servico
            }
        }
        $uri = "$(($Script:baseUri).Split('microsoft.operationalinsights')[0])Microsoft.OperationsManagement/solutions/SecurityInsights($WorkspaceName)?api-version=2015-11-01-preview"

        try
        {
            $solutionResult = Invoke-webrequest -Uri $uri -Method Get -Headers $script:authHeader
            Write-Output "Azure Sentinel is already enabled on $WorkspaceName and status is: $($solutionResult.StatusDescription)"
        } catch
        {
            $errorReturn = $_
            $errorResult = ($errorReturn | ConvertFrom-Json ).error
            if ($errorResult.Code -eq 'ResourceNotFound')
            {
                Write-Output "Azure Sentinetal is not enabled on workspace: $($WorkspaceName)"
                try
                {
                    if ($PSCmdlet.ShouldProcess("Do you want to enable Sentinel for Workspace: $workspace"))
                    {
                        $result = Invoke-webrequest -Uri $uri -Method Put -Headers $script:authHeader -Body ($body | ConvertTo-Json)
                        Write-Output "Successfully enabled Sentinel on workspae: $WorkspaceName with result code $($result.StatusDescription)"
                    } else
                    {
                        Write-Output "No change have been made for $WorkspaceName, deployment aborted"
                        break
                    }
                } catch
                {
                    Write-Verbose $_
                    Write-Error "Unable to enable Sentinel on $WorkspaceName with error message: $($_.Exception.Message)"
                }
            } else
            {
                Write-Verbose $_
                Write-Error "Unable to Azure Sentinel with error message: $($_.Exception.Message)" -ErrorAction Stop
            }
        }
    } else
    {
        Write-Error "Workspace $WorkspaceName is currently in $($workspaceResult.properties.provisioningState) status, setup canceled"
    }
}