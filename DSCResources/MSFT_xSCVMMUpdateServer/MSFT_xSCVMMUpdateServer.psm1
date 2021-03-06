# NOTE: This resource requires WMF5 and PsDscRunAsCredential

# DSC resource to add a VMM Update Server.
# Runs on the VMM Management Server.

$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function ImportVMMModule
{
    try
    {
        if(!(Get-Module 'virtualmachinemanager'))
        {
            Write-Verbose 'Importing virtualmachinemanager module'
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            $null = Import-Module 'virtualmachinemanager' -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
            $true
        }
        else
        {
            $true
        }
    }
    catch
    {
        $VerbosePreference = $CurrentVerbose
        Write-Verbose 'Failed importing virtualmachinemanager module'
        $false
    }
}


function ConnectVMMServer
{
    if(ImportVMMModule)
    {
        try
        {
            Write-Verbose "Connecting to VMM server $($env:COMPUTERNAME)"
            Get-SCVMMServer -ComputerName $env:COMPUTERNAME
        }
        catch
        {
            throw New-TerminatingError -ErrorType FailedToConnectToVMMServer -FormatArgs @($env:COMPUTERNAME)
        }
    }
}


function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ComputerName
	)

    if(!$VMMServer)
    {
        $VMMServer = ConnectVMMServer
    }

    if($VMMServer)
    {
        try
        {
            Write-Verbose "cmdlet: Get-SCUpdateServer" -Verbose
            $UpdateServer = Get-SCUpdateServer -VMMServer $VMMServer -ComputerName $ComputerName -ErrorAction SilentlyContinue
            Write-Verbose "cmdlet succeeded" -Verbose
        }
        catch
        {
            Write-Verbose "cmdlet failed" -Verbose
        }
        finally
        {
            $VMMServer.Disconnect()
        }

        if($UpdateServer)
        {
            $Ensure = "Present"
        }
        else
        {
            $Ensure = "Absent"
        }
    }

	$returnValue = @{
		Ensure = $Ensure
		ComputerName = $ComputerName
		TCPPort = $UpdateServer.Port
		UseSSLConnection = $UpdateServer.IsConnectionSecure
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$ComputerName,

		[System.UInt16]
		$TCPPort = 8530,

		[System.String]
		$RunAsAccount,

		[System.Boolean]
		$UseSSLConnection,

		[System.Boolean]
		$StartUpdateServerSync
	)

    $VMMServer = ConnectVMMServer

    if($VMMServer)
    {
        
        try
        {
            Write-Verbose "cmdlet: Get-SCRunAsAccount" -Verbose
            $VMMRunAsAccount = Get-SCRunAsAccount -VMMServer $VMMServer -Name $RunAsAccount
            Write-Verbose "cmdlet succeeded" -Verbose
        }
        catch
        {
            Write-Verbose "cmdlet failed" -Verbose
            throw $_            
        }
        
        if($VMMRunAsAccount)
        {
            switch($Ensure)
            {
                "Present"
                {
                    try
                    {
                        Write-Verbose "cmdlet: Add-SCUpdateServer" -Verbose
                        if($UseSSLConnection)
                        {
                            $UpdateServer = Add-SCUpdateServer -VMMServer $VMMServer -ComputerName $ComputerName -TCPPort $TCPPort -Credential $VMMRunAsAccount -UseSSLConnection
                        }
                        else
                        {
                            $UpdateServer = Add-SCUpdateServer -VMMServer $VMMServer -ComputerName $ComputerName -TCPPort $TCPPort -Credential $VMMRunAsAccount
                        }
                        Write-Verbose "cmdlet succeeded" -Verbose
                    }
                    catch
                    {
                        Write-Verbose "cmdlet failed" -Verbose
                        throw $_
                    }
                    if($UpdateServer -and $StartUpdateServerSync)
                    {
                        Start-SCUpdateServerSynchronization -VMMServer $VMMServer -UpdateServer $UpdateServer
                    }
                }
                "Absent"
                {
                    try
                    {
                        Write-Verbose "cmdlet: Get-SCUpdateServer | Remove-SCUpdateServer" -Verbose
                        $UpdateServer = Get-SCUpdateServer -VMMServer $VMMServer -ComputerName $ComputerName -ErrorAction SilentlyContinue
                        if($UpdateServer)
                        {
                            Remove-SCUpdateServer -VMMServer $VMMServer -UpdateServer $UpdateServer -Credential $VMMRunAsAccount
                        }
                        Write-Verbose "cmdlet succeeded" -Verbose
                    }
                    catch
                    {
                        Write-Verbose "cmdlet failed" -Verbose
                        throw $_
                    }
                }
            }
        }
    }

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
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$ComputerName,

		[System.UInt16]
		$TCPPort = 8530,

		[System.String]
		$RunAsAccount,

		[System.Boolean]
		$UseSSLConnection,

		[System.Boolean]
		$StartUpdateServerSync
	)

	$result = ((Get-TargetResource -ComputerName $ComputerName).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource