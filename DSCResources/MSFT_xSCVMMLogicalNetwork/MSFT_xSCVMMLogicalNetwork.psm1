$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Test-Requirements
{
    Try
    {
        If (-not (Get-Module VirtualMachineManager -ErrorAction SilentlyContinue))
        {
            Write-Verbose -Message "Importing the VirtualMachineManager PowerShell module"
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = "SilentlyContinue"
            $null = Import-Module VirtualMachineManager -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
        }
        $null = Get-SCVMMServer $env:COMPUTERNAME -ErrorAction Stop
    }
    Catch
    {
        Throw $PSItem.Exception
    }
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    Test-Requirements
    $LogicalNetwork = Get-SCLogicalNetwork -VMMServer $env:COMPUTERNAME -Name $Name
    If ($LogicalNetwork)
    {
        $Ensure = "Present"
        $Description = $LogicalNetwork.Description
        If (-not $LogicalNetwork.IsLogicalNetworkDefinitionIsolated)
        {
            $NetworkType = "Single"
        }
        ElseIf ($LogicalNetwork.IsPVLAN)
        {
            $NetworkType = "PVLAN"
        }
        Else
        {
            $NetworkType = "VLAN"
        }
        $EnableNetworkVirtualization = $LogicalNetwork.NetworkVirtualizationEnabled
    }
    Else
    {
        $Ensure = "Absent"
        $Description = ""
        $NetworkType = ""
        $EnableNetworkVirtualization = $false
    }

    $returnValue = `
    @{
        Ensure = $Ensure
        Name = $Name
        Description = $Description
        NetworkType = $NetworkType
        EnableNetworkVirtualization = $EnableNetworkVirtualization
    }
    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $false)]
        [System.String]
        $Description,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Single","VLAN","PVLAN")]
        [System.String]
        $NetworkType = "Single",
        
        [Parameter(Mandatory = $false)]
        [System.Boolean]
        $EnableNetworkVirtualization = $false
    )

    Test-Requirements
    If ($NetworkType -eq "Single")
    {
        $LogicalNetworkDefinitionIsolation = $false
        $IsPVLAN = $false
        If ($EnableNetworkVirtualization)
        {
            $UseGRE = $true
        }
        Else
        {
            $UseGRE = $false
        }
    }
    Else
    {
        $EnableNetworkVirtualization = $false
        $UseGRE = $false
        $LogicalNetworkDefinitionIsolation = $true
        If ($NetworkType -eq "VLAN")
        {
            $IsPVLAN = $false
        }
        Else
        {
            $IsPVLAN = $true
        }
    }
    If (-not $Description)
    {
        $Description = "$Name - DSC created Logical Network"
    }
    Switch ($Ensure)
    {
        "Present"
        {
            Try
            {
                $LogicalNetwork = Get-SCLogicalNetwork -VMMServer $env:COMPUTERNAME -Name $Name -ErrorAction Stop
                If ($LogicalNetwork)
                {
                    Write-Verbose -Message "Change properties of the Logical Network named '$($Name)'."
                    Set-SCLogicalNetwork -VMMServer $env:COMPUTERNAME -Name $Name -Description $Description -LogicalNetwork $LogicalNetwork -RunAsynchronously -EnableNetworkVirtualization $EnableNetworkVirtualization -UseGRE $UseGRE -LogicalNetworkDefinitionIsolation $LogicalNetworkDefinitionIsolation -ErrorAction Stop
                }
                Else
                {
                    Write-Verbose -Message "Create Logical Network named '$($Name)'."
                    New-SCLogicalNetwork -VMMServer $env:COMPUTERNAME -Name $Name -LogicalNetworkDefinitionIsolation $LogicalNetworkDefinitionIsolation -EnableNetworkVirtualization $EnableNetworkVirtualization -UseGRE $UseGRE -IsPVLAN $IsPVLAN -Description $Description -ErrorAction Stop
                }
            }
            Catch
            {
                Throw $PSItem.Exception
            }
        }
        "Absent"
        {
            Try
            {
                # NOTE: This could be tough to implement 100% as it must discover and remove any resources that are using this Logical Network first
                $LogicalNetwork = Get-SCLogicalNetwork -VMMServer $env:COMPUTERNAME -Name $Name -ErrorAction Stop
                If ($LogicalNetwork)
                {
                    Write-Verbose -Message "Remove any dependencies of Logical Network named '$($Name)'."
                    $VMNetwork = Get-SCVMNetwork -LogicalNetwork $LogicalNetwork
                    If ($VMNetwork.Count -gt 0)
                    {
                        Write-Verbose -Message "Removing VM Networks associated with this Logical Network."
                        ForEach ($VMNet In $VMNetwork)
                        {
                            $RemoveAdapters = (Get-SCVirtualNetworkAdapter -All | Where-Object { $PSItem.VMNetwork.ID -eq $VMNet.ID }) | Set-SCVirtualNetworkAdapter -NoLogicalNetwork -NoConnection -NoPortClassification
                            $DeleteGateways = (Get-SCVMNetworkGateway -VMNetwork $VMNet) | Remove-SCVMNetworkGateway -Confirm:$false
                            If (-not ($LogicalNetwork.IsLogicalNetworkDefinitionIsolated))
                            {
                                ForEach ($Subnet In (Get-SCVMSubnet -VMNetwork $VMNet))
                                {
                                    ForEach ($Pool In (Get-SCStaticIPAddressPool -VMSubnet $Subnet))
                                    {
                                        $RevokeIPs = Get-SCIPAddress -StaticIPAddressPool $Pool | Revoke-SCIPAddress
                                        $DeletePool = $Pool | Remove-SCStaticIPAddressPool -Confirm:$false
                                    }
                                    $DeleteSubnet = $Subnet | Remove-SCVMSubnet
                                }
                            }
                            Remove-SCVMNetwork $VMNet -Confirm:$false
                        }
                    }
                    $LogicalNetworkDefinition = Get-SCLogicalNetworkDefinition -LogicalNetwork $LogicalNetwork -ErrorAction Stop
                    If ($LogicalNetworkDefinition.Count -gt 0)
                    {
                        ForEach ($ThisLogicalNetworkDef In $LogicalNetworkDefinition)
                        {
                            $StaticIPAddressPools = Get-SCStaticIPAddressPool -LogicalNetworkDefinition $ThisLogicalNetworkDef -ErrorAction Stop
                            If ($StaticIPAddressPools.Count -gt 0)
                            {
                                Write-Verbose -Message "Removing Static IP Address Pools associated with this Logical Network."
                                ForEach ($Pool In $StaticIPAddressPools)
                                {
                                    $RevokeIPs = Get-SCIPAddress -StaticIPAddressPool $Pool | Revoke-SCIPAddress
                                    $DeletePool = $Pool | Remove-SCStaticIPAddressPool -Confirm:$false
                                }
                            }
                            Write-Verbose -Message "Removing Logical Network Definition '$($ThisLogicalNetworkDef.Name)' associated with this Logical Network."
                            Remove-SCLogicalNetworkDefinition -LogicalNetworkDefinition $ThisLogicalNetworkDef -ErrorAction Stop
                        }
                    }
                    Write-Verbose -Message "Removing the Logical Network named '$($Name)'."
                    $LogicalNetwork | Remove-SCLogicalNetwork
                }
            }
            Catch
            {
                Throw $PSItem.Exception
            }
        }
    }
    
    If (-not(Test-TargetResource @PSBoundParameters))
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
        [Parameter(Mandatory = $false)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $false)]
        [System.String]
        $Description,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Single","VLAN","PVLAN")]
        [System.String]
        $NetworkType = "Single",
        
        [Parameter(Mandatory = $false)]
        [System.Boolean]
        $EnableNetworkVirtualization = $false
    )

    Test-Requirements
    [System.Boolean]$result = $true
    $CurrentConfig = Get-TargetResource -Name $Name
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: Logical Network named '$($Name)' is '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        Write-Verbose -Message "Validate Logical Network named '$($Name)'."
        If ($Description)
        {
            If ($CurrentConfig.Description -ne $Description)
            {
                Write-Verbose -Message "FAIL: Description is incorrect."
                $result = $false
            }
        }
        If ($NetworkType)
        {
            If ($CurrentConfig.NetworkType -ne $NetworkType)
            {
                Write-Verbose -Message "FAIL: NetworkType is '$($CurrentConfig.NetworkType)' when it should be '$($NetworkType)'."
                $result = $false
            }
        }
        If ($CurrentConfig.EnableNetworkVirtualization -ne $EnableNetworkVirtualization)
        {
            Write-Verbose -Message "FAIL: NetworkVirtualization setting is incorrect."
            $result = $false
        }
    }
    return $result
}

Export-ModuleMember -Function *-TargetResource
