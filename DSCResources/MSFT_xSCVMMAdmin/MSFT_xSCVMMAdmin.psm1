# NOTE: This resource requires WMF5 and PsDscRunAsCredential

# DSC resource to manage VMM admin role.
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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$Principal,

		[parameter(Mandatory = $true)]
		[System.String]
		$UserRole
	)

    if(!$VMMServer)
    {
        $VMMServer = ConnectVMMServer
    }

    if($VMMServer)
    {
        try
        {
            Write-Verbose "cmdlet: Get-SCUserRole" -Verbose
            if(Get-SCUserRole -VMMServer $env:COMPUTERNAME -Name $UserRole | ForEach-Object {$_.Members} | Where-Object {$_.Name -eq $Principal})
            {
                $Ensure = "Present"
            }
            else
            {
                $Ensure = "Absent"
            }
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
    }

    $returnValue = @{
        Ensure = $Ensure
        Principal = $Principal
        UserRole = $UserRole
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
		$Principal,

		[parameter(Mandatory = $true)]
		[System.String]
		$UserRole
	)

    $VMMServer = ConnectVMMServer

    if($VMMServer)
    {
        try
        {
            Write-Verbose "cmdlet: Get-SCUserRole | Set-SCUserRole" -Verbose
            switch($Ensure)
            {
                "Present"
                {
                    if(!(Get-SCUserRole -VMMServer $env:COMPUTERNAME -Name $UserRole | ForEach-Object {$_.Members} | Where-Object {$_.Name -eq $Principal}))
                    {
                        Get-SCUserRole -VMMServer $env:COMPUTERNAME -Name $UserRole | Set-SCUserRole -AddMember $Principal
                    }
                }
                "Absent"
                {
                    if(Get-SCUserRole -VMMServer $env:COMPUTERNAME -Name $UserRole | ForEach-Object {$_.Members} | Where-Object {$_.Name -eq $Principal})
                    {
                        Get-SCUserRole -VMMServer $env:COMPUTERNAME -Name $UserRole | Set-SCUserRole -RemoveMember $Principal
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
		$Principal,

		[parameter(Mandatory = $true)]
		[System.String]
		$UserRole
	)

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource