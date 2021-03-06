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
		$LogicalUnitName,

		[parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,

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

    $logicalUnit = $storageProvider.StorageArrays.StoragePools.StorageLogicalUnits | Where-Object {$_.Name -eq $LogicalUnitName}
    if (!($logicalUnit))
    {
        throw New-TerminatingError -ErrorType StorageLogicalUnitNotFound -FormatArgs @($LogicalUnitName, $StorageProviderName) -ErrorCategory ObjectNotFound
    }

    $hostCluster = Get-SCVMHostCluster -Name $HostClusterName -VMMServer $vmmConnection -ErrorAction Stop
    if (!($hostCluster))
    {
        throw New-TerminatingError -ErrorType HostClusterNotFound -FormatArgs @($HostClusterName) -ErrorCategory ObjectNotFound
    }

    $lun = Compare-Object $logicalUnit.SMLunId $hostCluster.SharedVolumes.StorageDisk.SMLunId -IncludeEqual | Where-Object {$_.SideIndicator -eq '=='}
    if( $lun -ne $null)
    {
        Write-Verbose -Message "$functionName $LogicalUnitName is already registered to $HostClusterName."
        $Ensure = "Present"
    }
    else
    {
        $Ensure = "Absent"
    }

    $FoundClassificationName = $logicalUnit.Classification.Name
    foreach ($storageDisk in $hostCluster.SharedVolumes.StorageDisk)
    {
        if ($storageDisk.SMLunId -eq $logicalUnit.SMLunId)
        {
            # If classification is manually set on the disk it overrides the one inherited from the storage array.
            Write-Verbose -Message "Found $($storageDisk.Classification.Name) on disk SMLunId: $($storageDisk.SMLunId)."
            $FoundClassificationName = $storageDisk.Classification.Name
        }
    }

    Write-Verbose -Message "$functionName Found $FoundClassificationName on LUN: $LogicalUnitName and $HostClusterName."

	$returnValue = @{
		StorageLogicalUnitName = $logicalUnit.Name
		StorageProviderName = $storageProvider.Name
        Ensure = $Ensure
		HostClusterName = $hostCluster.Name
        ClassificationName = $FoundClassificationName
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
		$LogicalUnitName,

		[parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,
        
        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
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
		$LogicalUnitName,

		[parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,
        
        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

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
		$LogicalUnitName,

		[parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,
        
        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

        [System.String]
		$ClassificationName,

        [Switch]$Apply
	) 
    
    $functionName = $($MyInvocation.MyCommand.Name) + ":"
  
    try
    {
        $vmmServerName = $env:COMPUTERNAME
        if ($Apply)
        {
            $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName
        }

        $resourceProperties = Get-TargetResource -LogicalUnitName $LogicalUnitName -StorageProviderName $StorageProviderName -HostClusterName $HostClusterName -ClassificationName $ClassificationName
        if ($Ensure -eq "Present")
        {
            if ($resourceProperties['Ensure'] -eq "Absent")
            {
                if ($Apply) 
                {
                    $storageProvider = Get-SCStorageProvider -Name $StorageProviderName -VMMServer $vmmConnection -ErrorAction Stop                                                                                      
                    $logicalUnit = $storageProvider.StorageArrays.StoragePools.StorageLogicalUnits | Where-Object {$_.Name -eq $LogicalUnitName}

                    $hostCluster = Get-SCVMHostCluster -Name $HostClusterName -VMMServer $vmmConnection -ErrorAction Stop

                    Write-Verbose -Message "$functionName Working on LUN: $($logicalUnit.Name)."
                    
                    Register-SCStorageLogicalUnit -StorageLogicalUnit $logicalUnit -VMHostCluster $hostCluster -ErrorAction Stop

                    Write-Verbose -Message "$functionName Registered $($logicalUnit.Name) to $($hostCluster.Name)"

                    # If we registered the LUN then assign the required classification
                    if ($PSBoundParameters.ContainsKey('ClassificationName'))
                    {
                        $classification = Get-SCStorageClassification -Name $ClassificationName -VMMServer $vmmConnection -ErrorAction Stop

                        $storageDisks = Get-SCStorageDisk -VMMServer $vmmConnection | Where-Object {$_.SMLunId -eq $logicalUnit.SMLunId}
                        foreach($storageDisk in $storageDisks)
                        {
                            Write-Verbose -Message "$functionName Assigned classification $ClassificationName for storage disk: $($storageDisk.Name) (SMLunId:$($storageDisk.SMLunId), $($storageDisk.VMHost.Name)) corresponding to LUN: $($logicalUnit.Name)."
                            Set-SCStorageDisk -StorageDisk $storageDisk -StorageClassification $classification
                        }
                    }
                }
                else
                {
                    return $false
                }
            }
            else
            {
                if ($PSBoundParameters.ContainsKey('ClassificationName'))
                {
                    if ($resourceProperties['ClassificationName'] -ne $ClassificationName)
                    {
                        if ($Apply) 
                        {
                            $storageProvider = Get-SCStorageProvider -Name $StorageProviderName -VMMServer $vmmConnection -ErrorAction Stop                                                                                      
                            $logicalUnit = $storageProvider.StorageArrays.StoragePools.StorageLogicalUnits | Where-Object {$_.Name -eq $LogicalUnitName}

                            $classification = Get-SCStorageClassification -Name $ClassificationName -VMMServer $vmmConnection -ErrorAction Stop

                            $storageDisks = Get-SCStorageDisk -VMMServer $vmmConnection | Where-Object {$_.SMLunId -eq $logicalUnit.SMLunId}
                            foreach($storageDisk in $storageDisks)
                            {
                                Write-Verbose -Message "$functionName Assigned classification $ClassificationName for storage disk: $($storageDisk.Name) (SMLunId:$($storageDisk.SMLunId), $($storageDisk.VMHost.Name)) corresponding to LUN: $($logicalUnit.Name)."
                                Set-SCStorageDisk -StorageDisk $storageDisk -StorageClassification $classification
                            }
                        }
                        else
                        {
                            return $false
                        }
                    }
                }

                if (!($Apply))
                {
                    return $true
                } 
            }
        }
        elseif ($Ensure -eq "Absent")
        {
            Write-Verbose "Error occured in $functionName."

            throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
        }
        else
        { 
            Write-Verbose "Error occured in $functionName."
            throw New-TerminatingError -ErrorType InvalidEnsureValue
        }
        
    }
    catch
    {
        Write-Verbose -Message "$functionName has failed! Message: $_ ."
        throw $_
    }
}


Export-ModuleMember -Function *-TargetResource

