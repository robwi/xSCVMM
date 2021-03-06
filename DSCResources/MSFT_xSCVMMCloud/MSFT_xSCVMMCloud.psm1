 <#
.SYNOPSIS
   SCVMMCloud DSC Module.

.DESCRIPTION
    DSC Module for adding VMM Cloud. 
    Must run on the VMM Server using DSCRunAs account. 
#>

$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
		[String]
		$Name,

		[String]
		$Description,

        [String[]]
        $HostGroupNames = @('All Hosts'),

        [String[]]
        $ReadLibraryShareNames,

        [String[]]
        $LogicalNetworkNames,

        [String[]]
        $LoadBalancerNames,

        [String[]]
        $PortClassificationNames,

        [String[]]
        $StorageClassificationNames
	)
    
    $vmmConnection = Get-VMMServerConnection

    Write-Verbose "Getting Cloud: ""$Name""."

    $cloud = Get-SCCloud -Name $Name -VMMServer $vmmConnection

    if($cloud)
    {
        $cloudHostGroupNames = @()
        $cloudReadLibraryShareNames = @()
        $LogicalNetworkNames = @()
        $LoadBalancerNames = @()
        $PortClassificationNames = @()
        $StorageClassificationNames = @()

        $cloud.HostGroup | Foreach-Object {  $cloudHostGroupNames += $_.Name }
        $cloud.ReadableLibraryPaths | Foreach-Object {  $cloudReadLibraryShareNames += $_.Name }

        $cloud.LogicalNetworks | ForEach-Object {

            $LogicalNetworkNames += $_.Name
        } 

        $cloud.LoadBalancers | ForEach-Object {
                    
            $LoadBalancerNames += $_.Name 
        }

        $cloud.PortClassifications | ForEach-Object {
                
            $PortClassificationNames += $_.Name 
        }

        $cloud.StorageClassifications | ForEach-Object {

            $StorageClassificationNames += $_.Name 
        }

        $returnValue = @{
            Ensure = 'Present'
            Name = $cloud.Name
            Description = $cloud.Description
            HostGroupNames = $cloudHostGroupNames
            ReadLibraryShareNames = $cloudReadLibraryShareNames
            LogicalNetworkNames = $LogicalNetworkNames
            LoadBalancerNames = $LoadBalancerNames
            PortClassificationNames = $PortClassificationNames
            StorageClassificationNames = $StorageClassificationNames }
    }
    else
    {
        $returnValue = @{
            Ensure = 'Absent'
            Name = $Name
            Description = $null
            HostGroupNames = $null
            ReadLibraryShareNames = $null
            LogicalNetworkNames = $null
            LoadBalancerNames = $null
            PortClassificationNames = $null
            StorageClassificationNames = $null }
    }

	$returnValue
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
		[String]
		$Name,

		[String]
		$Description,

        [String[]]
        $HostGroupNames = @('All Hosts'),

        [String[]]
        $ReadLibraryShareNames,

        [String[]]
        $LogicalNetworkNames,

        [String[]]
        $LoadBalancerNames,

        [String[]]
        $PortClassificationNames,

        [String[]]
        $StorageClassificationNames
	)
    
    $vmmConnection = Get-VMMServerConnection

    Write-Verbose "Getting Cloud: ""$Name""."

    $cloud = Get-SCCloud -Name $Name -VMMServer $vmmConnection -ErrorAction Stop 

    switch($Ensure)
    {
        "Present"
        {
            $currentCloud = Get-TargetResource @PSBoundParameters

            $updateCloudParameters = @{}
            $resources = @()
            
            if($LogicalNetworkNames)
            {
                $LogicalNetworkNames | ForEach-Object {

                    if($_ -notin $currentCloud.LogicalNetworkNames)
                    {
                        $result = Get-SCLogicalNetwork -All -Name $_ -VMMServer $vmmConnection -ErrorAction Stop

                        if($result)
                        {
                            $resources += $result
                        }
                        else
                        {
                             throw New-TerminatingError -ErrorType LogicalNetworkNotFound `
                                                        -FormatArgs @($_) `
                                                        -ErrorCategory ObjectNotFound
                        }
                    }
                } 
            }

            if($LoadBalancerNames)
            {
                # Note:  Libary shares cannot be queried by name so you must query all
                $allLoadBalancers = Get-SCLoadBalancer -All -VMMServer $vmmConnection -ErrorAction Stop

                $LoadBalancerNames | ForEach-Object {
                    
                    $loadBalancerName = $_

                    if($loadBalancerName -notin $currentCloud.LoadBalancerNames)
                    {
                        $result = $allLoadBalancers | Where { $_.Name -eq $loadBalancerName }

                        if($result)
                        {
                            $resources += $result
                        }
                        else
                        {
                             throw New-TerminatingError -ErrorType LoadBalancerNotFound `
                                                        -FormatArgs @($loadBalancerName) `
                                                        -ErrorCategory ObjectNotFound
                        }
                    }
                }
            }

            if($PortClassificationNames)
            {
                $PortClassificationNames | ForEach-Object {

                    if($_ -notin $currentCloud.PortClassificationNames)
                    {
                        $result = Get-SCPortClassification -Name $_ -VMMServer $vmmConnection -ErrorAction Stop

                        if($result)
                        {
                            $resources += $result
                        }
                        else
                        {
                             throw New-TerminatingError -ErrorType PortClassificationNotFound `
                                                        -FormatArgs @($_) `
                                                        -ErrorCategory ObjectNotFound
                        }
                    }
                }
            }

            if($StorageClassificationNames)
            {
                $StorageClassificationNames | ForEach-Object {

                    if($_ -notin $currentCloud.StorageClassificationNames)
                    {
                        $result = Get-SCStorageClassification -Name $_ -VMMServer $vmmConnection -ErrorAction Stop

                        if($result)
                        {
                            $resources += $result
                        }
                        else
                        {
                             throw New-TerminatingError -ErrorType StorageClassificationNotFound `
                                                        -FormatArgs @($_) `
                                                        -ErrorCategory ObjectNotFound
                        }
                    }
                }
            }

            if($resources)
            {
                $updateCloudParameters["AddCloudResource"] = $resources
            }

            if($HostGroupNames)
            {
                Write-Verbose "Getting all VMHostGroups"

                $hostGroups = @()

                $HostGroupNames | ForEach-Object {
                        
                    if($_ -notin $currentCloud.HostGroupNames)
                    {
                        $result = Get-SCVMHostGroup -Name $_ -VMMServer $vmmConnection -ErrorAction Stop

                        if($result)
                        {
                            $hostGroups += $result
                        }
                        else
                        {
                            throw New-TerminatingError -ErrorType HostGroupNotFound `
                                                       -FormatArgs @($_) `
                                                       -ErrorCategory ObjectNotFound
                        }
                    }
                }

                $updateCloudParameters["AddVMHostGroup"] = $hostGroups
            }

            if($ReadLibraryShareNames)
            {
                Write-Verbose "Getting all LibraryShares"

                $readlibraryShares = @()

                # Note:  Libary shares cannot be queried by name so you must query all
                $allLibraryShares = Get-SCLibraryShare -VMMServer $vmmConnection

                $ReadLibraryShareNames | ForEach-Object {
                    
                    $readlibraryShareName = $_
                                        
                    if($readlibraryShareName -notin $currentCloud.ReadLibraryShareNames)
                    {
                        $result = $allLibraryShares | Where { $_.Name -eq $readlibraryShareName}

                        if($result)
                        {
                            $readlibraryShares += $result 
                        }
                        else
                        {
                            throw New-TerminatingError -ErrorType LibraryShareNotFound `
                                                       -FormatArgs @($readlibraryShareName) `
                                                       -ErrorCategory ObjectNotFound
                        }
                    }
                }

                $updateCloudParameters["AddReadOnlyLibraryShare"] = $readlibraryShares
            }
                
            if(!$cloud)
            {
                Write-Verbose "Creating Cloud: ""$Name""."

                $cloud = New-SCCloud -Name $Name -VMHostGroup $HostGroups -VMMServer $vmmConnection -ErrorAction Stop
            }

            $updateCloudParameters["Cloud"] = $cloud
            $updateCloudParameters["Description"] = $Description
            
            Write-Verbose "Updating cloud properties."

            # Support for adding new cloud properties supported but not for removing cloud properties, manual removal required
            $null = Set-SCCloud @updateCloudParameters -VMMServer $vmmConnection -ErrorAction Stop 

            Write-Verbose "Setting cloud max capacity."

            $null = Set-SCCloudCapacity `
                -CloudCapacity $cloud.CloudCapacity `
                -UseCustomQuotaCountMaximum $true `
                -UseMemoryMBMaximum $true `
                -UseCPUCountMaximum $true `
                -UseStorageGBMaximum $true `
                -UseVMCountMaximum $true `
                -VMMServer $vmmConnection `
                -ErrorAction Stop
        }
        "Absent"
        {
            if($cloud)
            {
                $null = Remove-SCCloud -Cloud $cloud -ErrorAction Stop
            }
        }
    }

    # For now call Test at the end of Set
    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType TestFailedAfterSet -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
		[String]
		$Name,

		[String]
		$Description,

        [String[]]
        $HostGroupNames = @('All Hosts'),

        [String[]]
        $ReadLibraryShareNames,

        [String[]]
        $LogicalNetworkNames,

        [String[]]
        $LoadBalancerNames,

        [String[]]
        $PortClassificationNames,

        [String[]]
        $StorageClassificationNames
	)

    $retVal = Get-TargetResource @PSBoundParameters

    if($retVal.Ensure -ne $Ensure)
    {
        Write-Verbose "Expected Ensure: ""$Ensure"" Actual: ""$($retVal.Ensure)""." 

        return $false
    }

    if($retVal.Ensure -eq "Absent")
    {
        return $true
    }

    $result = $true

    if($Description -ne $retVal.Description)
    {
        Write-Verbose "Expected Description: ""$Description"" Actual: ""$($retVal.Description)""." 

        $result = $false
    }
    
    if(!(Compare-ObjectAssert -ExpectedArray $HostGroupNames `
                            -ActualArray $retVal.HostGroupNames `
                            -MessageName "HostGroupNames"))
    {
        $result = $false
    }

    if(!(Compare-ObjectAssert -ExpectedArray $ReadLibraryShareNames `
                            -ActualArray $retVal.ReadLibraryShareNames `
                            -MessageName "ReadLibraryShareNames"))
    {
	    $result = $false
    }

    if(!(Compare-ObjectAssert -ExpectedArray $LogicalNetworkNames `
                            -ActualArray $retVal.LogicalNetworkNames `
                            -MessageName "LogicalNetworkNames"))
    {
	    $result = $false
    }

    if(!(Compare-ObjectAssert -ExpectedArray $LoadBalancerNames `
                            -ActualArray $retVal.LoadBalancerNames `
                            -MessageName "LoadBalancerNames"))
    {
	    $result = $false
    }

    if(!(Compare-ObjectAssert -ExpectedArray $PortClassificationNames `
                            -ActualArray $retVal.PortClassificationNames `
                            -MessageName "PortClassificationNames"))
    {
	    $result = $false
    }

    if(!(Compare-ObjectAssert -ExpectedArray $StorageClassificationNames `
                            -ActualArray $retVal.StorageClassificationNames `
                            -MessageName "StorageClassificationNames"))
    {
	    $result = $false
    }

    $result
}

Export-ModuleMember -Function *-TargetResource