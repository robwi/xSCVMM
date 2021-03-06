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
		$FileServerName
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    $vmmServerName = $env:COMPUTERNAME
    $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

    $fileServer = Get-SCStorageFileServer -Name $FileServerName -VMMServer $vmmConnection                                                                                       
    $fileShare = $fileServer.StorageFileShares | Where-Object {$_.Name -eq $Name}

    if (!($fileShare))
    {
        Write-Verbose -Message "$functionName We didn't find a storage file share with name $Name on file server $FileServerName."
        $Ensure = 'Absent'
    }
    else
    {
        Write-Verbose -Message "$functionName Found storage file share with name $Name (Path: $($fileShare.SharePath)) on file server $FileServerName."
        $Ensure = 'Present'
    }

	$returnValue = @{
		Name = $Name
        FileServerName = $FileServerName
        Ensure = $Ensure
        IsManaged = $fileShare.IsManaged
        ClassificationName = $fileShare.StorageClassification.Name
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
		$FileServerName,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
		[System.Boolean]
		$IsManaged = $false,

        [System.String]
		$ClassificationName
	)

    ValidateOrApply-Resource @PSBoundParameters -Apply

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
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$FileServerName,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
		[System.Boolean]
		$IsManaged = $false,

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
		$Name,

        [parameter(Mandatory = $true)]
		[System.String]
		$FileServerName,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",
        
		[System.Boolean]
		$IsManaged = $false,

        [System.String]
		$ClassificationName,

        [Switch]$Apply
	) 
    
    $functionName = $($MyInvocation.MyCommand.Name) + ":"
  
    try
    {
        $vmmServerName = $env:COMPUTERNAME
        $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

        $resourceProperties = Get-TargetResource -Name $Name -FileServerName $FileServerName
        if ($Ensure -eq "Present")
        {
            if ($resourceProperties['Ensure'] -eq "Absent")
            {
                if ($Apply) 
                {
                    $StorageProviders = Get-SCStorageProvider -VMMServer $vmmConnection | Where-Object {($_.StorageArrays.Name -contains $FileServerName) -or ($_.StorageFileServerss.Name -contains $FileServerName)}
                    foreach($StorageProvider in $StorageProviders)
                    {
                        Write-Verbose -Message "$functionName Refreshing storage provider $($StorageProvider.Name)"
                        $null = Read-SCStorageProvider -StorageProvider $storageProvider -Force -ErrorAction Stop
                    }
                }
                else
                {
                    Write-Verbose -Message "$functionName Storage file share $Name does not exists on file server $FileServerName."
                    return $false
                }
            }

            $fileServer = Get-SCStorageFileServer -Name $FileServerName -VMMServer $vmmConnection                                                                                       
            $fileShare = $fileServer.StorageFileShares | Where-Object {$_.Name -eq $Name}

            if ($fileShare.IsManaged -ne $IsManaged)
            {
                if ($Apply)
                {
                    $null = Set-SCStorageFileServer -StorageFileServer $fileServer -AddStorageFileShareToManagement $fileShare -ErrorAction Stop
                }
                else
                {
                    return $false
                }
            }

            if ($fileShare.StorageClassification.Name -ne $ClassificationName)
            {
                if ($Apply)
                {
                    $classification = Get-SCStorageClassification -Name $ClassificationName -VMMServer $vmmConnection
                    if (!($classification))
                    {
                        Write-Verbose "Error occured in $functionName."

                        throw New-TerminatingError -ErrorType ClassificationNotFound -FormatArgs @($classification) -ErrorCategory ObjectNotFound
                    }
                    else
                    {
                        Write-Verbose -Message "$functionName Found storage classification $ClassificationName."
                    }
                    Set-SCStorageFileShare -StorageFileShare $fileShare -StorageClassification $classification -ErrorAction Stop
                }
                else
                {
                    return $false
                }
            }

            if (!($Apply))
            {
                return $true
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

