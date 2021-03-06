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
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    $vmmServerName = $env:COMPUTERNAME
    $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

    $storageProvider = Get-SCStorageProvider -Name $StorageProviderName -VMMServer $vmmConnection -ErrorAction Stop                                                                                      
    if (!($storageProvider))
    {
        throw New-TerminatingError -ErrorType StorageProviderNotFound -FormatArgs @($($storageProvider.Name)) -ErrorCategory ObjectNotFound
    }

    $logicalUnit = $storageProvider.StorageArrays.StoragePools.StorageLogicalUnits | Where-Object {$_.Name -eq $Name}
    if (!($logicalUnit))
    {
        Write-Verbose -Message "$functionName We didn't find a storage logical unit with name $Name on storage provider $StorageProviderName."
        $Ensure = 'Absent'
    }
    else
    {
        Write-Verbose -Message "$functionName Found storage storage logical unit with name $Name (SMLunId: $($logicalUnit.SMLunId)) on storage provider $StorageProviderName."
        $Ensure = 'Present'
    }

	$returnValue = @{
        Name = $Name
        StorageProviderName = $StorageProviderName
        Ensure = $Ensure
        HostGroupName = $logicalUnit.HostGroup.Name
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
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
		[System.String]
		$HostGroupName
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
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
		[System.String]
		$HostGroupName
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
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$StorageProviderName,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
		[System.String]
		$HostGroupName,

        [Switch]$Apply
	) 
    
    $functionName = $($MyInvocation.MyCommand.Name) + ":"
  
    try
    {
        $vmmServerName = $env:COMPUTERNAME
        $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

        $resourceProperties = Get-TargetResource -Name $Name -StorageProviderName $StorageProviderName
        if ($Ensure -eq "Present")
        {
            if ($resourceProperties['Ensure'] -eq "Absent")
            {
                if ($Apply) 
                {
                    Write-Verbose -Message "$wfName Creating new LUN with name $Name on storage provider $StorageProviderName."
                    throw New-TerminatingError -ErrorType PreCreatedStorage -ErrorCategory NotImplemented
                }
                else
                {
                    Write-Verbose -Message "$functionName LUN with name $Name does not exists on storage provider $StorageProviderName."
                    return $false
                }
            }
            else
            {   
                $storageProvider = Get-SCStorageProvider -Name $StorageProviderName -VMMServer $vmmConnection -ErrorAction Stop
                $logicalUnit = $storageProvider.StorageArrays.StoragePools.StorageLogicalUnits | Where-Object {$_.Name -eq $Name}

                if ($PSBoundParameters.ContainsKey('HostGroupName'))
                {
                    # Check for host group
                    if ($logicalUnit.HostGroup.Name -ne $HostGroupName)
                    {
                        if ($Apply)
                        {
                            $hostGroup = Get-SCVMHostGroup -Name $HostGroupName -VMMServer $vmmConnection -ErrorAction Stop
                            if (!($hostGroup))
                            {
                                throw New-TerminatingError -ErrorType HostGroupNotFound -FormatArgs @($HostGroupName) -ErrorCategory ObjectNotFound
                            }
                            else
                            {
                                Write-Verbose -Message "$functionName Found host group $HostGroupName."
                            }

                            Write-Verbose -Message "$functionName Setting host group $HostGroupName for storage logical unit with name $Name (SMLunId: $($logicalUnit.SMLunId))."
                            Set-SCStorageLogicalUnit -StorageLogicalUnit $logicalUnit -VMHostGroup $hostGroup -ErrorAction Stop
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
            throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
        }
        else
        { 
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

