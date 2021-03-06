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
		$HostOrClusterName,

        [parameter(Mandatory = $true)]
		[System.String]
		$RegisteryKeyIfRefreshVirtualMachines
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    #$Key = "HKLM:\SOFTWARE\Microsoft\Cloud Solutions"
    $KeyName = "IfRefreshVirtualMachines"
    $IfRefreshVirtualMachines = Get-RegistryKeyValue -Key $RegisteryKeyIfRefreshVirtualMachines -KeyName $KeyName

	$returnValue = @{
		HostOrClusterName = $HostOrClusterName
        RegisteryKeyIfRefreshVirtualMachines = $RegisteryKeyIfRefreshVirtualMachines
		IfRefreshVirtualMachines = $IfRefreshVirtualMachines
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
		$HostOrClusterName,

        [parameter(Mandatory = $true)]
		[System.String]
		$RegisteryKeyIfRefreshVirtualMachines
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
		$HostOrClusterName,

        [parameter(Mandatory = $true)]
		[System.String]
		$RegisteryKeyIfRefreshVirtualMachines
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
		$HostOrClusterName,

        [parameter(Mandatory = $true)]
		[System.String]
		$RegisteryKeyIfRefreshVirtualMachines,

        [Switch]$Apply
	) 
    
    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    try
    {
        $resourceProperties = Get-TargetResource -HostOrClusterName $HostOrClusterName -RegisteryKeyIfRefreshVirtualMachines $RegisteryKeyIfRefreshVirtualMachines

        if( $resourceProperties['IfRefreshVirtualMachines'] -eq $true)
        {
            if ($Apply)
            {
                $vmmServerName = $env:COMPUTERNAME
                $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

                $hostCluster = Get-SCVMHostCluster -Name $HostOrClusterName -VMMServer $vmmConnection
                if($hostCluster -ne $null)
                {
                    foreach($node in $hostCluster.Nodes)
                    {
                        $vms = Get-SCVirtualMachine -VMMServer $vmmConnection -VMHost $node | Where-Object {$_.Status -in @('IncompleteVMConfig','UnsupportedSharedFiles','UnsupportedCluster')}
                        Write-Verbose -Message "$functionName Refreshing all $($vms.Count) of the virtual machines on $($node.Name) and cluster $hostCluster"
                        foreach ($vm in $vms)
                        {
                            Write-Verbose -Message "$functionName Refreshing $($vm.Name) virtual machines on $($node.Name) and cluster $hostCluster"
                            Read-SCVirtualMachine -VM $vm -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
                else
                {
                    $vmHost = Get-SCVMHost -ComputerName $HostOrClusterName -VMMServer $vmmConnection 
                    $vms = Get-SCVirtualMachine -VMMServer $vmmConnection -VMHost $vmHost | Where-Object {$_.Status -in @('IncompleteVMConfig','UnsupportedSharedFiles','UnsupportedCluster')}
                    Write-Verbose -Message "$functionName here Refreshing all $($vms.Count) of the virtual machines on $HostOrClusterName"
                    foreach ($vm in $vms)
                    {
                        Write-Verbose -Message "$functionName here Refreshing $($vm.Name) virtual machines on $HostOrClusterName"
                        Read-SCVirtualMachine -VM $vm -ErrorAction SilentlyContinue | Out-Null
                    }
                }

                Write-Verbose -Message "Refreshing Operations Manager connection after VM refresh"
                Write-SCOpsMgrConnection -VMMServer $vmmConnection
            }
            else
            {
                return $false
            }
        }
        else
        {
            if (!($Apply))
            {
                return $true
            }
        }

    }
    catch
    {
        Write-Verbose -Message "$functionName has failed! Message: $_ ."
        throw $_
    }
}

Export-ModuleMember -Function *-TargetResource

