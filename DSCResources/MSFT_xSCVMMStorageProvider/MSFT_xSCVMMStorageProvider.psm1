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
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Type,

		[System.UInt32]
		$TCPPort,

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"
    $vmmServerName = $env:COMPUTERNAME

    Assert-Module -ModuleName VirtualMachineManager

    $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

    
    switch($Type)
    {
        "WindowsNativeWmi" 
        {
            $computerName = $Name
        }

        "SmisCimXml"
        {
            $uri = [System.Uri]$Name
            $computerName = $uri.Host
        }
    }  

    $storageProvider = Get-SCStorageProvider -Name $computerName -VMMServer $vmmConnection
    if($storageProvider)
    {
        if($storageProvider.Status -ne 'Responding')
        {
            Write-Verbose -Message "$functionName Storage provider status is $($storageProvider.Status)"
            $Ensure = 'Absent'
        }
        else
        {
            Write-Verbose -Message "$functionName Found responding storage provider $storageProvider and full name $Name."
            $Ensure = 'Present'
        }
    }
    else
    {
        Write-Verbose -Message "$functionName We didn't find a storage provider with IP or FQDN: $computerName and full name $Name."
        $Ensure = 'Absent'
    }

	$returnValue = @{
		Name = $Name
        Type = $storageProvider.ProviderType
        TCPPort = $storageProvider.TCPPort
        Ensure = $Ensure
		RunAsAccountName = $RunAsAccountName
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Name,

        [parameter(Mandatory = $true)]
        [ValidateSet("SmisCimXml","WindowsNativeWmi")]
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Type,

        [System.UInt32]
		$TCPPort,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
		$RunAsAccountName
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
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
        [ValidateSet("SmisCimXml","WindowsNativeWmi")]
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Type,

        [System.UInt32]
		$TCPPort,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
		$RunAsAccountName
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
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
        [ValidateSet("SmisCimXml","WindowsNativeWmi")]
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Type,

        [System.UInt32]
		$TCPPort,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
		$RunAsAccountName,

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

        $resourceProperties = Get-TargetResource -Name $Name -Type $Type -TCPPort $TCPPort -RunAsAccountName $RunAsAccountName
        if ($Ensure -eq "Present")
        {
            if ($resourceProperties['Ensure'] -eq "Absent")
            {
                if ($Apply) 
                {
                    $runAsAccount = Get-SCRunAsAccount -Name $RunAsAccountName -VMMServer $vmmConnection
                    if (!($runAsAccount))
                    {
                        throw New-TerminatingError -ErrorType RunAsAccountNotFound -FormatArgs @($RunAsAccountName) -ErrorCategory ObjectNotFound
                    }
                    else
                    {
                        Write-Verbose -Message "$functionName Found RunAs account with name $runAsAccount." 
                    }

                    Write-Verbose -Message "$functionName Adding storage provider $Name. This would discover all the storage objects."
                    
                    switch($Type)
                    {
                        "WindowsNativeWmi" 
                        {
                            $storageProvider = Add-SCStorageProvider -ComputerName $Name -AddWindowsNativeWmiProvider -Name $Name -RunAsAccount $runAsAccount -ErrorAction Stop
                        }

                        "SmisCimXml"
                        {
                            $uri = [System.Uri]$Name
                            $computerName = $uri.Host
                            if(!($storageProvider = Get-SCStorageProvider -Name $computerName -VMMServer $vmmConnection))
                            {
                                Write-Verbose -Message "$functionName Working with protocol $($uri.Scheme) on $($uri.Host)."
                                if ($uri.Scheme -eq "https")
                                {
                                    $certificate = Get-SCCertificate -ComputerName $computerName -TCPPort $TCPPort
                                    $storageProvider = Add-SCStorageProvider -NetworkDeviceName $Name -TCPPort $TCPPort -Name $computerName -Certificate $certificate -RunAsAccount $runAsAccount -ErrorAction Stop
                                }
                                else
                                {
                                    $storageProvider = Add-SCStorageProvider -NetworkDeviceName $Name -TCPPort $TCPPort -Name $computerName -RunAsAccount $runAsAccount -ErrorAction Stop
                                }
                            }
                        }
                    }
                    
                    Write-Verbose -Message "$functionName Refreshing storage provider"
                    $null = Read-SCStorageProvider -StorageProvider $storageProvider -Force -ErrorAction Stop
                }
                else
                {
                    Write-Verbose -Message "$functionName Storage Provider $Name does not exists."
                    return $false
                }
            }
            else
            {
                if ($Apply) 
                {
                    $storageProvider = Get-SCStorageProvider -Name $Name -VMMServer $vmmConnection
                    Write-Verbose -Message "$functionName Retrieved storage provider with name $Name. Refreshing it." 
                    $null = Read-SCStorageProvider -StorageProvider $storageProvider -Force -ErrorAction Stop
                }
                else
                {
                    Write-Verbose -Message "$functionName Found storage provider $Name. No need to do anything."
                    return $true
                }
            }
        }
        elseif( $Ensure -eq "Absent")
        {
            if( $resourceProperties['Ensure'] -eq "Present")
            {
                if($Apply) 
                {
                    switch($Type)
                    {
                        "WindowsNativeWmi" 
                        {
                            $computerName = $Name
                        }

                        "SmisCimXml"
                        {
                            $uri = [System.Uri]$Name
                            $computerName = $uri.Host
                        }
                    } 

                    Write-Verbose -Message "$functionName Removing storage provider $computerName and full name $Name."
                    $storageProvider = Get-SCStorageProvider -Name $computerName -VMMServer $vmmConnection
                    Remove-SCStorageProvider -StorageProvider $storageProvider
                }
                else
                {
                    return $false
                }
            }
            else
            {
                Write-Verbose -Message "$functionName Storage provider $Name already absent."
                if (!$Apply)
                {
                    return $true
                }
            }
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

