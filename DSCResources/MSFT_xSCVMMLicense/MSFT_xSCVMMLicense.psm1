# NOTE: This resource requires WMF5 and PsDscRunAsCredential

# DSC resource to manage VMM license.
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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$ProductKey
	)

    if(!$VMMServer)
    {
        $VMMServer = ConnectVMMServer
    }

    if($VMMServer)
    {
        try
        {
            Write-Verbose "Getting license type for VMM server $($env:COMPUTERNAME)"
            $LicenseType = (Get-SCVMMAccessLicense -VMMServer $VMMServer -License | Where-Object {$_.LicenseBy -eq 'ManagementServer'}).LicenseType
            Write-Verbose "License type for VMM server $($env:COMPUTERNAME) is $LicenseType"
            if($LicenseType -in @('Evaluation','Unknown'))
            {
                $Ensure = "Absent"
            }
            else
            {
                $Ensure = "Present"
            }
        }
        catch
        {
            Write-Verbose "Failed getting license type for VMM server $($env:COMPUTERNAME)"
            $Ensure = "Absent"
        }
        finally
        {
            $VMMServer.Disconnect()
        }
    }

    $returnValue = @{
        Ensure = $Ensure
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
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$ProductKey
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
                    Write-Verbose "Setting license for VMM server $($env:COMPUTERNAME)"
                    Register-SCVMMAccessLicense -VMMServer $VMMServer -ProductKey $ProductKey -AcceptEULA -ErrorAction Stop
                }
                catch
                {
                    Write-Verbose "Failed setting license for VMM server $($env:COMPUTERNAME)"
                }
            }
            "Absent"
            {
                throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
            }
        }
    }

    if(!(Test-TargetResource @PSBoundParameters))
    {
        Write-Verbose "Test-TargetResouce xSCVMM/xSCVMMLicense failed after Set-TargetResource"
        # Note: No throw since we want to allow this resource to fail
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
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$ProductKey
	)

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource