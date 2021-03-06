# DSC resource to attach a VMM agent to a VMM Management Server as a managed computer.
# Runs on the server that the agent is installed on.

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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$SCVMMManagementServer,

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccount,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential
	)

	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"

    $ManagedComputer = Invoke-Command -ComputerName $SCVMMManagementServer -Credential $SetupCredential {
        try
        {
            Write-Verbose "cmdlet: Get-SCVMMManagedComputer" -Verbose
            Get-SCVMMManagedComputer -VMMServer $env:COMPUTERNAME -ComputerName $using:ComputerName -ErrorAction SilentlyContinue
            Write-Verbose "cmdlet succeeded" -Verbose
        }
        catch
        {
            Write-Verbose "cmdlet failed" -Verbose
        }
    }

    if($ManagedComputer)
    {
        $Ensure = "Present"
        $Description = $ManagedComputer.Description
    }
    else
    {
        $Ensure = "Absent"
        $Description = ""
    }

	$returnValue = @{
		Ensure = $Ensure
		SCVMMManagementServer = $SCVMMManagementServer
		Description = $Description
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
		$SCVMMManagementServer,

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccount,

		[System.String]
		$Description,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential
	)

	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"

    Invoke-Command -ComputerName $SCVMMManagementServer -Credential $SetupCredential {
        $VMMServer = Get-SCVMMServer -ComputerName $env:COMPUTERNAME
        if($VMMServer)
        {
            $RunAsAccount = Get-SCRunAsAccount -VMMServer $using:VMMServer -Name $using:RunAsAccount
            switch($Ensure)
            {
                "Present"
                {
                    try
                    {
                        Write-Verbose "cmdlet: Add-SCVMMManagedComputer" -Verbose
                        if($using:Description)
                        {
                            Add-SCVMMManagedComputer -ComputerName $using:ComputerName -Credential $RunAsAccount -Description $using:Description
                        }
                        else
                        {
                            Add-SCVMMManagedComputer -ComputerName $using:ComputerName -Credential $RunAsAccount
                        }
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
                        Write-Verbose "cmdlet: Get-SCVMMManagedComputer | Remove-SCVMMManagedComputer" -Verbose
                        $ManagedComputer = Get-SCVMMManagedComputer -VMMServer $using:VMMServer -ComputerName $using:ComputerName
                        Remove-SCVMMManagedComputer -VMMManagedComputer $using:ManagedComputer -Credential $RunAsAccount
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
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$SCVMMManagementServer,

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccount,

		[System.String]
		$Description,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential
	)

	$result = ((Get-TargetResource -Ensure $Ensure -SCVMMManagementServer $SCVMMManagementServer -RunAsAccount $RunAsAccount -SetupCredential $SetupCredential).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource

