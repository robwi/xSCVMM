# NOTE: This resource requires WMF5 and PsDscRunAsCredential

# DSC resource to manage VMM runas accounts.
# Runs on VMM Management Server.

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
		$Name,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$Credential
	)

    if(!$VMMServer)
    {
        $VMMServer = ConnectVMMServer
    }

    if($VMMServer)
    {
        try
        {
            Write-Verbose "cmdlet: Get-SCRunAsAccount" -Verbose
            $RunAsAccounts = Get-SCRunAsAccount -VMMServer $env:COMPUTERNAME -Name $Name
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

        if(!($MatchDomain = $Credential.GetNetworkCredential().Domain))
        {
            $MatchDomain = $null
        }
        if($MatchedRunAsAccount = ($RunAsAccounts | Where-Object {($_.Domain -eq $MatchDomain) -and ($_.UserName -eq $Credential.GetNetworkCredential().UserName)}))
        {
            $Ensure = "Present"
            $Description = $MatchedRunAsAccount.Description
        }
        else
        {
            $Ensure = "Absent"
            $Description = ""
        }
    }

	$returnValue = @{
		Ensure = $Ensure
		Name = $Name
		Description = $Description
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
		$Name,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$Credential,

		[System.String]
		$Description,

		[System.Boolean]
		$NoValidation
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
                    Write-Verbose "cmdlet: New-SCRunAsAccount" -Verbose
                    New-SCRunAsAccount -VMMServer $env:COMPUTERNAME -Name $Name -Credential $Credential -Description $Description -NoValidation:$NoValidation
                    Write-Verbose "cmdlet succeeded" -Verbose
                }
                catch
                {
                    Write-Verbose "cmdlet failed" -Verbose
                    throw $_
                }
            }
            "Absent"
            {
                try
                {
                    Write-Verbose "cmdlet: Get-SCRunAsAccount | Remove-SCRunAsccount" -Verbose
                    Get-SCRunAsAccount -VMMServer $env:COMPUTERNAME -Name $Name | Where-Object {($_.Domain -eq ($Credential).GetNetworkCredential().Domain) -and ($_.UserName -eq ($Credential).GetNetworkCredential().UserName)} | Remove-SCRunAsAccount
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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$Credential,

		[System.String]
		$Description,

		[System.Boolean]
		$NoValidation
	)

	$result = ((Get-TargetResource -Name $Name -Credential $Credential).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource