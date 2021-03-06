# NOTE: This resource requires WMF5 and PsDscRunAsCredential, 
# Runs on VMM Management Server.

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
        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [System.Boolean]
		$PoolIsManaged = $false,

		[System.String]
		$HostGroupName,

		[System.String]
		$ClassificationName
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    $vmmServerName = $env:COMPUTERNAME
    $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

    $storageProvider = Get-SCStorageProvider -Name $StorageProviderName -VMMServer $vmmConnection -ErrorAction Stop                                                                                      
    if (!($storageProvider))
    {
        throw New-TerminatingError -ErrorType StorageProviderNotFound -FormatArgs @($($storageProvider.Name)) -ErrorCategory ObjectNotFound
    }

    $storageArrays = $storageProvider.StorageArrays
    if (($storageArrays -eq $null) -or ($storageArrays.Count -lt 1))
    {
        throw New-TerminatingError -ErrorType StorageArrayNotFound -FormatArgs @($StorageProviderName) -ErrorCategory ObjectNotFound
    }

    if ($storageArrays.Count -eq 1)
    {
        if ($storageArrays.StoragePools.Count -eq 1)
        {
            $PoolIsManaged = $storageArrays[0].StoragePools[0].IsManaged
            $ClassificationName =  $storageArrays[0].StoragePools[0].Classification.Name
            $HostGroupName = $storageArrays[0].StoragePools[0].HostGroup.Name
            $Name = $storageArrays[0].Name
        }
        else
        {
            throw New-TerminatingError -ErrorType Unsupported -FormatArgs @($($storageArrays[0].Name)) -ErrorCategory InvalidData
        }
    }
    else
    {
        throw New-TerminatingError -ErrorType Unsupported -FormatArgs @($StorageProviderName) -ErrorCategory InvalidData
    }

	$returnValue = @{
        StorageProviderName = $StorageProviderName
        PoolIsManaged = $PoolIsManaged
        HostGroupName = $HostGroupName
        ClassificationName = $ClassificationName
        Name = $Name
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [System.Boolean]
		$PoolIsManaged = $false,

        [System.String]
		$HostGroupName,

        [System.String]
		$ClassificationName
	)

    ValidateOrApply-Resource @PSBoundParameters -Apply
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [System.Boolean]
		$PoolIsManaged = $false,

        [System.String]
		$HostGroupName,

        [System.String]
		$ClassificationName
	)

    $isDesiredState = ValidateOrApply-Resource @PSBoundParameters

    return $isDesiredState
}

# This is an internal function that is either used by Test or Set for the resource based on the Apply flag.
#
function ValidateOrApply-Resource 
{ 
	[CmdletBinding()]
	param
	(
        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [System.Boolean]
		$PoolIsManaged = $false,

        [System.String]
		$HostGroupName,

        [System.String]
		$ClassificationName,

        [Switch]$Apply
	) 
    
    $functionName = $($MyInvocation.MyCommand.Name) + ":"
  
    try
    {
        $vmmServerName = $env:COMPUTERNAME
        $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

        $applyProperties = $false

        $resourceProperties = Get-TargetResource -StorageProviderName $StorageProviderName -PoolIsManaged $PoolIsManaged -HostGroupName $HostGroupName -ClassificationName $ClassificationName

        if ($PoolIsManaged -eq $true)
        {
            if ($resourceProperties['PoolIsManaged'] -eq $false)
            {
                if ($Apply) 
                {
                    $applyProperties = $true
                }
                else
                {
                    Write-Verbose -Message "$functionName Pool is not marked for management on storage provider $StorageProviderName."
                    return $false
                }
            }
            else
            {
                if ($resourceProperties['HostGroupName'] -ne $HostGroupName)
                {
                    if ($Apply) 
                    {
                        $applyProperties = $true
                    }
                    else
                    {
                        Write-Verbose -Message "$functionName On storage array checking host group, found: $($resourceProperties['HostGroupName']) but expected: $HostGroupName storage provider $StorageProviderName."
                        return $false
                    } 
                }

                if ($resourceProperties['ClassificationName'] -ne $ClassificationName)
                {
                    if ($Apply) 
                    {
                        $applyProperties = $true
                    }
                    else
                    {
                        Write-Verbose -Message "$functionName On storage array checking classification, found: $($resourceProperties['ClassificationName']) but expected: $ClassificationName storage provider $StorageProviderName."
                        return $false
                    } 
                }
            }

            if (!$Apply)
            {
                return $true
            }
            else
            {
                if ($applyProperties)
                {
                    $storageProvider = Get-SCStorageProvider -Name $StorageProviderName -VMMServer $vmmConnection -ErrorAction Stop  
                    $storageArray = $storageProvider.StorageArrays[0]

                    $storagePools = @()
                    $storagePools += Get-SCStoragePool -Name $storageArray.StoragePools[0].Name -VMMServer $vmmConnection -ErrorAction Stop

                    $classifications = @()
                    if ( !([string]::IsNullOrEmpty($ClassificationName)) )
                    {
                        $classifications += Get-SCStorageClassification -Name $ClassificationName -VMMServer $vmmConnection -ErrorAction Stop
                    }
                    else
                    {
                        throw New-TerminatingError -ErrorType StorageArrayClassificationNotSpecified -FormatArgs @($ClassificationName, $StorageProviderName) -ErrorCategory InvalidData
                    }

                    $hostGroups = @()
                    if ( !([string]::IsNullOrEmpty($HostGroupName)) )
                    {
                        $hostGroups += Get-SCVMHostGroup -Name $HostGroupName -VMMServer $vmmConnection
                    }

                    Write-Verbose -Message "$functionName Adding pools to VMM management, setting storage classification $ClassificationName and setting host group $HostGroupName on storage provider $StorageProviderName."
                    Set-SCStorageArray -StorageArray $storageArray -AddStoragePoolToManagement $storagePools -StorageClassificationAssociation $classifications -VMHostGroupAssociation $hostGroups -ErrorAction Stop
                }
            }
        }
        else
        {
            throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
        }              
    }
    catch
    {
        Write-Verbose -Message "$functionName has failed! Message: $_ ."
        throw $_
    }
}

Export-ModuleMember -Function *-TargetResource

