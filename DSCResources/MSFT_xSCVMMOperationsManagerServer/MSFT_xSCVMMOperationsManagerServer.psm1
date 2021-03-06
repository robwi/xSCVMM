# NOTE: This resource requires WMF5 and PsDscRunAsCredential

# DSC resource to connect VMM to OM.
# Runs on the VMM Management Server .

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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$OpsMgrServer,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$VMMServerCredential
	)

    if(!$VMMServer)
    {
        $VMMServer = ConnectVMMServer
    }

    if($VMMServer)
    {
        try
        {
            Write-Verbose "cmdlet: Get-SCOpsMgrConnection" -Verbose
            $SCOpsMgrConnection = Get-SCOpsMgrConnection -VMMServer $VMMServer -ErrorAction SilentlyContinue
            Write-Verbose "cmdlet succeeded" -Verbose
        }
        catch
        {
            Write-Verbose "cmdlet failed" -Verbose
            $Ensure = "Absent"
        }
        finally
        {
            $VMMServer.Disconnect()
        }

        if($SCOpsMgrConnection)
        {
            $Ensure = "Present"
            if(!($SCOpsMgrConnection.OpsMgrUserName))
            {
                $UseVMMServerServiceAccount = $true
            }
            else
            {
                $UseVMMServerServiceAccount = $false
            }
        }
        else
        {
            $Ensure = "Absent"
        }
    }

    $returnvalue = @{
		Ensure = $Ensure
		OpsMgrServer = $SCOpsMgrConnection.OpsMgrServerName
		EnablePRO = $SCOpsMgrConnection.PROEnabled
		EnableMaintenanceModeIntegration = $SCOpsMgrConnection.MaintenanceModeEnabled
		OpsMgrServerCredential = $SCOpsMgrConnection.OpsMgrUserName
		UseVMMServerServiceAccount = $UseVMMServerServiceAccount
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$OpsMgrServer,

		[System.Boolean]
		$EnablePRO,

		[System.Boolean]
		$EnableMaintenanceModeIntegration,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$VMMServerCredential,

		[System.String]
		$OpsMgrServerCredential,

		[System.Boolean]
		$UseVMMServerServiceAccount
	)

    $VMMServer = ConnectVMMServer

    if($VMMServer)
    {
        switch($Ensure)
        {
            "Present"
            {
                try
                {
                    Write-Verbose "cmdlet: New-SCOpsMgrConnection" -Verbose
                    switch($UseVMMServerServiceAccount)
                    {
                        $true
                        {
                            New-SCOpsMgrConnection -OpsMgrServer $OpsMgrServer -EnablePRO $EnablePro -EnableMaintenanceModeIntegration $EnableMaintenanceModeIntegration -VMMServerCredential $VMMServerCredential -UseVMMServerServiceAccount -RunAsynchronously
                        }
                        $false
                        {
                            $OpsMgrServerRunAs = Get-SCRunAsAccount -Name $OpsMgrServerCredential -VMMServer $VMMServer
                            if($OpsMgrServerRunAs)
                            {
                                New-SCOpsMgrConnection -OpsMgrServer $OpsMgrServer -EnablePRO $EnablePro -EnableMaintenanceModeIntegration $EnableMaintenanceModeIntegration -VMMServerCredential $VMMServerCredential -OpsMgrServerCredential $OpsMgrServerRunAs -RunAsynchronously
                            }
                        }
                    }
                    Write-Verbose "cmdlet succeeded" -Verbose
                }
                catch
                {
                    Write-Verbose "cmdlet failed" -Verbose
                    throw $_
                }
                while(Get-SCJob -Running | Where-Object {$_.CmdletName -eq "New-SCOpsMgrConnection"})
                {
                    Start-Sleep 1
                }
            }
            "Absent"
            {
                try
                {
                    Write-Verbose "cmdlet: Remove-SCOpsMgrConnection" -Verbose
                    Remove-SCOpsMgrConnection -VMMServer $VMMServer
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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$OpsMgrServer,

		[System.Boolean]
		$EnablePRO,

		[System.Boolean]
		$EnableMaintenanceModeIntegration,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$VMMServerCredential,

		[System.String]
		$OpsMgrServerCredential,

		[System.Boolean]
		$UseVMMServerServiceAccount
	)

    $result = ((Get-TargetResource -Ensure $Ensure -OpsMgrServer $OpsMgrServer -VMMServerCredential $VMMServerCredential).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource