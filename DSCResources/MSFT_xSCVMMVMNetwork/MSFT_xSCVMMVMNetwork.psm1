$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

<#
    Connected VM Networks via Network Service Gateways is NOT in scope for this DCS Resource at this time.

    VM Network Name does not have to be unique in VMM
    When using WindowsNetworkVirtualization isolation, there can be multiple VM Networks with the same Name and Subnets
    For these reasons, this module will assume that the VM Network Name is unique for each Logical Network
#>

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

function Remove-ThisVMNetwork
{
    $ThisErrorActionPref = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    Try
    {
        Write-Verbose -Message "Remove dependent resources for VM Network named '$($Name)'."
        $RemoveAdapters = (Get-SCVirtualNetworkAdapter -All | Where-Object VMNetwork -match $Name) | Set-SCVirtualNetworkAdapter -NoLogicalNetwork -NoConnection -NoPortClassification
        $DeleteGateways = (Get-SCVMNetworkGateway -VMNetwork $ThisVMNetwork) | Remove-SCVMNetworkGateway -Confirm:$false
        If (-not ($ThisLogicalNetwork.IsLogicalNetworkDefinitionIsolated))
        {
            ForEach ($Subnet In (Get-SCVMSubnet -VMNetwork $ThisVMNetwork))
            {
                ForEach ($Pool In (Get-SCStaticIPAddressPool -VMSubnet $Subnet))
                {
                    $RevokeIPs = Get-SCIPAddress -StaticIPAddressPool $Pool | Revoke-SCIPAddress
                    $DeletePool = $Pool | Remove-SCStaticIPAddressPool -Confirm:$false
                }
                $DeleteSubnet = $Subnet | Remove-SCVMSubnet
            }
        }
        Write-Verbose -Message "Remove VM Network named '$($Name)'."
        $remove = $ThisVMNetwork | Remove-SCVMNetwork -Confirm:$false
    }
    Catch
    {
        Throw $PSItem.Exception
    }
    $ErrorActionPreference = $ThisErrorActionPref
}

function Create-VlanBasedNetwork
{
    If ($ThisLogicalNetwork.IsPVLAN)
    {
        Write-Debug -Message "Logical Network is 'PVLAN' type"
        If (-not $NetworkSite)
        {
            throw New-TerminatingError -ErrorType MustSpecifySiteSubnet 
        }
        $ThisNetworkSite = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisLogicalNetwork -Name $NetworkSite
        If (-not $ThisNetworkSite)
        {
            throw New-TerminatingError -ErrorType NetworkSiteNotFound -FormatArgs @($NetworkSite,$LogicalNetwork) -ErrorCategory ObjectNotFound
        }
        $FoundSubnet = $ThisNetworkSite.SubnetVLans | Where-Object { ($PSItem.Subnet -eq $Subnet) -and ($PSItem.VLanID -eq $VlanId) -and ($PSItem.SecondaryVLanID -eq $SecondaryVlanId) }
        If (-not $FoundSubnet)
        {
            [System.String]$SubnetVlan = $Subnet + "-" + $VlanId + "-" + $SecondaryVlanId

            throw New-TerminatingError -ErroType SubnetVlanMatchNotFound -FormatArgs @($SubnetVlan) -ErrorCategory ObjectNotFound
        }
        If ($ExistingSubnets -contains ($Subnet+ "-" + $VlanId + "-" + $SecondaryVlanId))
        {
            throw New-TerminatingError -ErrorType SubnetAlreadyAssigned -FormatArgs @($Subnet)
        }
        Try
        {
            Write-Verbose -Message "Create new VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
            $vmNetwork = New-SCVMNetwork -Name $Name -LogicalNetwork $ThisLogicalNetwork -IsolationType "VLANNetwork" -Description $Description -VMMServer $env:COMPUTERNAME -ErrorAction Stop
            Write-Debug -Message "Create SubnetVlan Subnet: '$($Subnet)' VLanID: '$($VlanId)' SecondaryVLanID: '$($SecondaryVlanId)'."
            $SubnetVlan = New-SCSubnetVLan -Subnet $Subnet -VLanID $VlanId -SecondaryVLanID $SecondaryVlanId
            $vmSubnet = New-SCVMSubnet -Name $SubnetName -LogicalNetworkDefinition $ThisNetworkSite -SubnetVLan $SubnetVlan -VMNetwork $vmNetwork -VMMServer $env:COMPUTERNAME -ErrorAction Stop
        }
        Catch
        {
            If ($vmNetwork)
            {
                $remove = $vmNetwork | Remove-SCVMNetwork
            }
            Throw "$($_.Exception.Message)."
        }
    }
    Else
    {
        Write-Debug -Message "Logical Network is 'VLAN' type"
        If ($AutoCreateSubnet)
        {
            Try
            {
                Write-Verbose -Message "Create new VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)' and AutoCreate the Subnet."
                $vmNetwork = New-SCVMNetwork -AutoCreateSubnet -Name $Name -LogicalNetwork $ThisLogicalNetwork -Description $Description -VMMServer $env:COMPUTERNAME -ErrorAction Stop
            }
            Catch
            {
                If ($vmNetwork)
                {
                    $ThisVMNetwork = $vmNetwork
                    Remove-ThisVMNetwork
                }
                Throw "$($_.Exception.Message)."
            }
        }
        Else
        {
            If (-not $NetworkSite )
            {
                throw New-TerminatingError -ErrorType MustSpecifySiteSubnet 
            }
            $ThisNetworkSite = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisLogicalNetwork -Name $NetworkSite
            If (-not $ThisNetworkSite)
            {
                throw New-TerminatingError -ErrorType NetworkSiteNotFound -FormatArgs @($NetworkSite,$LogicalNetwork) -ErrorCategory ObjectNotFound 
            }
            $FoundSubnet = $ThisNetworkSite.SubnetVLans | Where-Object { ($PSItem.Subnet -eq $Subnet) -and ($PSItem.VLanID -eq $VlanId) -and ($PSItem.SecondaryVLanID -eq $SecondaryVlanId) }
            If (-not $FoundSubnet)
            {
                [System.String]$SubnetVlan = $Subnet + "-" + $VlanId + "-" + $SecondaryVlanId

                throw New-TerminatingError -ErroType SubnetVlanMatchNotFound -FormatArgs @($SubnetVlan) -ErrorCategory ObjectNotFound
            }
            If ($ExistingSubnets -contains ($Subnet+ "-" + $VlanId + "-" + $SecondaryVlanId))
            {
                throw New-TerminatingError -ErrorType SubnetAlreadyAssigned -FormatArgs @($Subnet)
            }
            Try
            {
                Write-Verbose -Message "Create new VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
                $vmNetwork = New-SCVMNetwork -Name $Name -LogicalNetwork $ThisLogicalNetwork -IsolationType "VLANNetwork" -Description $Description -VMMServer $env:COMPUTERNAME -ErrorAction Stop
                Write-Debug -Message "Create SubnetVlan Subnet: '$($Subnet)' VLanID: '$($VlanId)' SecondaryVLanID: '$($SecondaryVlanId)'."
                $SubnetVlan = New-SCSubnetVLan -Subnet $Subnet -VLanID $VlanId
                $vmSubnet = New-SCVMSubnet -Name $SubnetName -LogicalNetworkDefinition $ThisNetworkSite -SubnetVLan $SubnetVlan -VMNetwork $vmNetwork -VMMServer $env:COMPUTERNAME -ErrorAction Stop
            }
            Catch
            {
                If ($vmNetwork)
                {
                    $ThisVMNetwork = $vmNetwork
                    Remove-ThisVMNetwork
                }
                Throw "$($_.Exception.Message)."
            }
        }
    }
    $ThisVMNetwork = Get-SCVMNetwork -VMMServer $env:COMPUTERNAME -LogicalNetwork $ThisLogicalNetwork -Name $Name -ErrorAction Stop
    If ($ThisVMNetwork.VMSubnet.SubnetVLans.Subnet)
    {
        If ($Subnet -ne $ThisVMNetwork.VMSubnet.SubnetVLans.Subnet)
        {
            Write-Debug -Message "'$($Subnet)' does not match '$($ThisVMNetwork.VMSubnet.SubnetVLans.Subnet)'."

            throw New-TerminatingError -ErrorType FailedToSetSubnet -FormatArgs @($Subnet)
        }
    }
    Else
    {
        throw New-TerminatingError -ErrorType FailedToSetSubnet -FormatArgs @($Subnet)
    }
}

function Test-IsValidSubnet
{
    param
    (
        [System.String]$Subnet
    )
    
    If ($Subnet.Split('/').Count -ne 2)
    {
        return $false
    }
    Else
    {
        [System.String]$SubnetAddress = $Subnet.Split('/')[0]
        [System.String]$SubnetPrefix = $Subnet.Split('/')[1]
        If ([System.Net.IPAddress]::TryParse($SubnetAddress,[ref]$null))
        {
            If ($SubnetAddress -notmatch [System.Net.IPAddress]$SubnetAddress)
            {
                return $false
            }
        }
        Else
        {
            return $false
        }
        [int]$MinLength = 4
        [int]$MaxLength = 30
        If (([System.Net.IPAddress]$SubnetAddress).AddressFamily -eq "InterNetworkV6")
        {
            $MinLength = 64
            $MaxLength = 126
        }
        If ([int32]::TryParse($SubnetPrefix,[ref]$null))
        {
            If (-not(([int]$SubnetPrefix -ge $MinLength) -and ([int]$SubnetPrefix -le $MaxLength)))
            {
                return $false
            }
        }
        Else
        {
            return $false
        }
    }
    return $true
}

function Test-IsValidVlan
{
    param
    (
        [System.String]$VlanId
    )

    If ([int32]::TryParse($VlanId,[ref]$null))
    {
        If (-not(([int]$VlanId -ge 0) -and ([int]$VlanId -lt 4096)))
        {
            return $false
        }
    }
    Else
    {
        return $false
    }
    return $true
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,
        
        [Parameter(Mandatory = $true)]
        [System.String]
        $LogicalNetwork
    )
    
    Test-Requirements
    Try
    {
        $ThisLogicalNetwork = Get-SCLogicalNetwork -Name $LogicalNetwork -VMMServer $env:COMPUTERNAME -ErrorAction Stop
        $ThisVMNetwork = @()
        If ($ThisLogicalNetwork)
        {
            $ThisVMNetwork = Get-SCVMNetwork -VMMServer $env:COMPUTERNAME -LogicalNetwork $ThisLogicalNetwork -Name $Name -ErrorAction Stop
        }
    }
    Catch
    {
        Throw $PSItem.Exception
    }
    If ($ThisVMNetwork)
    {
        If ($ThisVMNetwork.Count -gt 1)
        {
            throw New-TerminatingError -ErrorType MultipleNetworksFound -FormatArgs @($Name,$LogicalNetwork)
        }
        Else
        {
            $Ensure = "Present"
            $Description = $ThisVMNetwork.Description
            $LogicalNetwork = $ThisVMNetwork.LogicalNetwork.Name
            $IsolationVMNetworkProtocol = $ThisVMNetwork.PAIPAddressPoolType
            $IsolationLogicalNetworkProtocol = $ThisVMNetwork.CAIPAddressPoolType
            $IsolationType = $ThisVMNetwork.IsolationType
            $VMSubnets = @()
            If ($ThisVMNetwork.VMSubnet.Count -gt 0)
            {
                ForEach ($Subnet In $ThisVMNetwork.VMSubnet)
                {
                    ForEach ($SubnetVlan In $Subnet.SubnetVlans)
                    {
                        [System.String]$AddItem = ($Subnet.Name + ";" + $SubnetVlan.Subnet + "-" + $SubnetVlan.VLanID + "-" + $SubnetVlan.SecondaryVLanID)
                        Write-Debug -Message "Found subnet: $AddItem"
                        $VMSubnets += $AddItem
                    }
                }
            }
        }
    }
    Else
    {
        $Ensure = "Absent"
        $Description = $null
        $LogicalNetwork = $null
        $IsolationVMNetworkProtocol = $null
        $IsolationLogicalNetworkProtocol = $null
        $IsolationType = $null
        $VMSubnets = @()
    }
    
    $returnValue = @{
        Ensure = [System.String]$Ensure
        Name = [System.String]$Name
        Description = [System.String]$Description
        LogicalNetwork = [System.String]$LogicalNetwork
        IsolationVMNetworkProtocol = [System.String]$IsolationVMNetworkProtocol
        IsolationLogicalNetworkProtocol = [System.String]$IsolationLogicalNetworkProtocol
        IsolationType = [System.String]$IsolationType
        VMSubnets = [System.String[]]$VMSubnets
    }
    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",
        
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,
        
        [System.String]
        $Description,
        
        [Parameter(Mandatory = $true)]
        [System.String]
        $LogicalNetwork,
        
        [ValidateSet("IPv4","IPv6")]
        [System.String]
        $IsolationVMNetworkProtocol,
        
        [ValidateSet("IPv4","IPv6")]
        [System.String]
        $IsolationLogicalNetworkProtocol,
        
        [System.String[]]
        $VMSubnets,
        
        [System.Boolean]
        $AutoCreateSubnet,
        
        [System.String]
        $NetworkSite,
        
        [System.Boolean]
        $StrictConfiguration = $false
    )
    
    Test-Requirements
    If (-not $Description)
    {
        $Description = "$Name - DSC created VM Network"
    }
    $ThisLogicalNetwork = Get-SCLogicalNetwork -Name $LogicalNetwork
    If (-not $ThisLogicalNetwork)
    {
        throw New-TerminatingError -ErrorType LogicalNetworkNotFound -FormatArgs @($LogicalNetwork)
    }
    $ThisVMNetwork = Get-SCVMNetwork -Name $Name -LogicalNetwork $ThisLogicalNetwork
    Switch ($Ensure)
    {
        "Present"
        {
            $IPv4Subnets = 0
            $IPv6Subnets = 0
            $ExistingSubnets = @()
            $LNDSubnets = @()
            $ThisLogicalNetworkDefs = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisLogicalNetwork
            If ($ThisLogicalNetworkDefs)
            {
                ForEach ($LNDef In $ThisLogicalNetworkDefs)
                {
                    ForEach ($SubnetVlan In $LNDef.SubnetVLans)
                    {
                        [System.String]$AddItem = ($SubnetVlan.Subnet + "-" + $SubnetVlan.VLanID + "-" + $SubnetVlan.SecondaryVLanID)
                        $LNDSubnets += $AddItem
                        $Protocol = "UNKNOWN"
                        $SubnetAddress = $SubnetVlan.Subnet.Split('/')[0]
                        If (([System.Net.IPAddress]$SubnetAddress).AddressFamily -eq "InterNetworkV6")
                        {
                            $IPv6Subnets++
                            $Protocol = "IPv6"
                        }
                        ElseIf (([System.Net.IPAddress]$SubnetAddress).AddressFamily -eq "InterNetwork")
                        {
                            $IPv4Subnets++
                            $Protocol = "IPv4"
                        }
                        Write-Debug -Message "Logical Network Definition '$($LNDef.Name)' contains the '$($Protocol)' subnet '$($AddItem)'."
                    }
                }
            }
            $NoIsolation = 0
            $ExistingVMNetworks = Get-SCVMNetwork -LogicalNetwork $ThisLogicalNetwork
            If ($ExistingVMNetworks)
            {
                ForEach ($Network In $ExistingVMNetworks)
                {
                    If ($Network.IsolationType -eq "NoIsolation")
                    {
                        $NoIsolation++
                    }
                }
                ForEach ($Subnet In $ExistingVMNetworks.VMSubnet)
                {
                    ForEach ($SubnetVlan In $Subnet.SubnetVlans)
                    {
                        [System.String]$AddItem = ($SubnetVlan.Subnet + "-" + $SubnetVlan.VLanID + "-" + $SubnetVlan.SecondaryVLanID)
                        Write-Debug -Message "VM Network exists for the subnet '$($AddItem)'."
                        $ExistingSubnets += $AddItem
                    }
                }
            }
            If ($ThisLogicalNetwork.IsLogicalNetworkDefinitionIsolated)
            {
                # The type of Logical Network is VLAN or PVLAN
                If ($IsolationVMNetworkProtocol -or $IsolationLogicalNetworkProtocol)
                {
                    Write-Warning -Message "VLAN/PVLAN-based Logical Networks do not support protocol-based isolation."
                    Remove-Variable IsolationVMNetworkProtocol
                    Remove-Variable IsolationLogicalNetworkProtocol
                }
                If (-not $ThisVMNetwork)
                {
                    $BadLogicalNetwork = $false
                    If ($ThisLogicalNetworkDefs.Count -eq 0)
                    {
                        Write-Debug -Message "No Logical Network Definitions found on the specified Logical Network."
                        $BadLogicalNetwork = $true
                    }
                    ElseIf ($ExistingSubnets.Count -ge $LNDSubnets.Count)
                    {
                        Write-Debug -Message "Logical Network has '$($LNDSubnets.Count)' SubnetVlans and '$($ExistingSubnets.Count)' have already been used by existing VM Networks."
                        $BadLogicalNetwork = $true
                    }
                    If ($BadLogicalNetwork)
                    {
                        throw New-TerminatingError -ErrorType LogicalNetworkNoResources
                    }
                }
                If ($VMSubnets.Count -gt 1)
                {
                    Write-Warning -Message "VM Networks on VLAN/PVLAN-based Logical Networks can only have a single subnet assigned."
                    $VMSubnets = @($VMSubnets[0])
                }
                If ($VMSubnets.Count -eq 0)
                {
                    If ($ThisLogicalNetwork.IsPVLAN)
                    {
                        throw New-TerminatingError -ErrorType MustSpecifySiteSubnet
                    }
                    ElseIf (-not $AutoCreateSubnet)
                    {
                        throw New-TerminatingError -ErrorType MustSpecifySiteSubnetOrAutoCreate
                    }
                }
                ElseIf ($VMSubnets.Count -eq 1)
                {
                    If ($VMSubnets[0].Split(';').Count -ne 2)
                    {
                        throw New-TerminatingError -ErrorType SubnetFormatError -FormatArgs @($VMSubnets[0])
                    }
                    $SubnetName = $VMSubnets[0].Split(';')[0]
                    If (-not $SubnetName)
                    {
                        $SubnetName = $Name + "_0"
                    }
                    $SubnetVlan = $VMSubnets[0].Split(';')[1]
                    [System.String]$Subnet = $SubnetVlan.Split('-')[0]
                    [System.String]$VlanId = '0'
                    [System.String]$SecondaryVlanId = '0'
                    If ($SubnetVlan.Split('-').Count -gt 1)
                    {
                        $VlanId = $SubnetVlan.Split('-')[1]
                        If ($VlanId -eq $null)
                        {
                            $VlanId = '0'
                        }
                    }
                    If ($ThisLogicalNetwork.IsPVLAN)
                    {
                        If ($SubnetVlan.Split('-').Count -gt 2)
                        {
                            $SecondaryVlanId = $SubnetVlan.Split('-')[2]
                            If ($SecondaryVlanId -eq $null)
                            {
                                $SecondaryVlanId = '0'
                            }
                        }
                    }
                    If (-not (Test-IsValidSubnet $Subnet))
                    {
                        throw New-TerminatingError -ErrorType InvalidSubnet -FormatArgs @($Subnet)
                    }
                    If (-not (Test-IsValidVlan $VlanId))
                    {
                        throw New-TerminatingError -ErrorType InvalidVlan -FormatArgs @($VlanId)
                    }
                    If (-not (Test-IsValidVlan $SecondaryVlanId))
                    {
                        throw New-TerminatingError -ErrorType InvalidSecondVlan -FormatArgs @($SecondaryVlanId)
                    }
                }
                If ($ThisVMNetwork)
                {
                        Write-Verbose -Message "Change VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
                    Write-Verbose -Message "Subnet/VLAN settings on VM Networks based on VLAN-type Logical Networks cannot be changed, they must be removed and re-created."
                    Remove-ThisVMNetwork
                    Create-VlanBasedNetwork
                        }
                        Else
                        {
                    Create-VlanBasedNetwork
                }
            }
            Else
            {
                If ($ThisVMNetwork)
                {
                    $ParamSet = `
                    @{
                        Description = $Description
                        VMNetwork = $ThisVMNetwork
                    }
                }
                Else
                {
                    $ParamSet = `
                    @{
                        Name = $Name
                        Description = $Description
                        LogicalNetwork = $ThisLogicalNetwork
                    }
                    If (($NoIsolation -ge 1) -and (-not ($IsolationVMNetworkProtocol -or $IsolationLogicalNetworkProtocol)))
                    {
                        throw New-TerminatingError -ErrorType MultipleNonIsolationNetworks
                    }
                }
                If ($ThisLogicalNetwork.NetworkVirtualizationEnabled)
                {
                    Write-Debug -Message "Logical Network is 'One Connected Network' type with Network Virtualization enabled"
                    If (($IsolationLogicalNetworkProtocol -eq "IPv4") -and ($IPv4Subnets -eq 0))
                    {
                        throw New-TerminatingError -ErrorType NoIP4ProtocolError
                    }
                    If (($IsolationLogicalNetworkProtocol -eq "IPv6") -and ($IPv6Subnets -eq 0))
                    {
                        throw New-TerminatingError -ErrorType NoIP6ProtocolError
                    }
                    If ($VMSubnets.Count -ge 1)
                    {
                        If (-not($IsolationLogicalNetworkProtocol -and $IsolationVMNetworkProtocol))
                        {
                            throw New-TerminatingError -ErrorType MustSpecifyNetworkAndLogicalNetworkProtocol
                        }
                        $AddSubnet = @()
                        $Id = 0
                        ForEach ($Network In $VMSubnets)
                        {
                            If ($Network.Split(';').Count -ne 2)
                            {
                                throw New-TerminatingError -ErrorType SubnetFormatError -FormatArgs @($VMSubnets[0])
                            }
                            $SubnetName = $Network.Split(';')[0]
                            If (-not $SubnetName)
                            {
                                $SubnetName = $Name + "_" + $Id
                                $Id++
                            }
                            $SubnetVlan = $Network.Split(';')[1]
                            [System.String]$Subnet = $SubnetVlan.Split('-')[0]
                            If (-not (Test-IsValidSubnet $Subnet))
                            {
                                throw New-TerminatingError -ErrorType InvalidAddress -FormatArgs @($Subnet)
                            }
                            $SubnetAddress = $Subnet.Split('/')[0]
                            If (($IsolationVMNetworkProtocol -eq "IPv4") -and (([System.Net.IPAddress]$SubnetAddress).AddressFamily -eq "InterNetworkV6"))
                            {
                                throw New-TerminatingError -ErrorType InvalidIsolationIPv4 -FormatArgs @($IsolationVMNetworkProtocol, $Subnet)
                            }
                            If (($IsolationVMNetworkProtocol -eq "IPv6") -and (([System.Net.IPAddress]$SubnetAddress).AddressFamily -eq "InterNetwork"))
                            {
                                throw New-TerminatingError -ErrorType InvalidIsolationIPv6 -FormatArgs @($IsolationVMNetworkProtocol, $Subnet)
                            }
                            Write-Debug -Message "Add Subnet: '$($Subnet)' Named: '$($SubnetName)'."
                            $AddSubnet += `
                            @{
                                Name = $SubnetName
                                Subnet = $Subnet
                            }
                        }
                    }
                    If ($NetworkSite)
                    {
                        Write-Warning -Message "NetworkSite cannot be specified for this type of Logical Network."
                    }
                    If ($ThisVMNetwork)
                    {
                        Write-Warning -Message "The VM Network named '$($Name)' for Logical Network '$($LogicalNetwork)' already exists."
                        $ParamSet += `
                        @{
                            ErrorAction = 'Stop'
                        }
                        Try
                        {
                            Write-Verbose -Message "Change new VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
                            $ParamSet.Keys | % { Write-Debug -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
                            $vmNetwork = Set-SCVMNetwork @ParamSet
                            If ($IsolationVMNetworkProtocol -and $IsolationLogicalNetworkProtocol)
                            {
                                $ExistingSubnetVlans = (Get-SCVMSubnet -VMNetwork $vmNetwork).SubnetVLans
                                ForEach ($Item In $AddSubnet)
                                {
                                    If ($ExistingSubnetVlans.Subnet -notcontains $Item.Subnet)
                                    {
                                        Write-Debug -Message "Create SubnetVlan Subnet: '$($Item.Subnet)' Name: '$($Item.Name)'."
                                        $NewSubnet = New-SCSubnetVLan -Subnet $Item.Subnet -ErrorAction Stop
                                        New-SCVMSubnet -Name $Item.Name -VMNetwork $vmNetwork -SubnetVLan $NewSubnet -ErrorAction Stop
                                    }
                                }
                                If ($StrictConfiguration)
                                {
                                    ForEach ($Item In (Get-SCVMSubnet -VMNetwork $vmNetwork))
                                    {
                                        If ($AddSubnet.Subnet -notcontains $Item.SubnetVLans.Subnet)
                                        {
                                            Write-Debug -Message "Remove SubnetVlan Subnet: '$($Item.SubnetVLans.Subnet)' Name: '$($Item.Name)'."
                                            $vmSubnet = Get-SCVMSubnet -Name $Item.Name -Subnet $Item.SubnetVLans.Subnet
                                            Remove-SCVMSubnet -VMSubnet $vmSubnet
                                        }
                                    }
                                }
                            }
                        }
                        Catch
                        {
                            Throw "$($_.Exception.Message)."
                        }
                    }
                    Else
                    {
                        If ($IsolationVMNetworkProtocol -and $IsolationLogicalNetworkProtocol)
                        {
                            $ParamSet += `
                            @{
                                IsolationType = "WindowsNetworkVirtualization"
                                CAIPAddressPoolType = $IsolationVMNetworkProtocol
                                PAIPAddressPoolType = $IsolationLogicalNetworkProtocol
                            }
                        }
                        Else
                        {
                            $ParamSet += `
                            @{
                                IsolationType = "NoIsolation"
                            }
                        }
                        $ParamSet += `
                        @{
                            ErrorAction = 'Stop'
                        }
                        Try
                        {
                            Write-Verbose -Message "Create new VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
                            $ParamSet.Keys | % { Write-Debug -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
                            $vmNetwork = New-SCVMNetwork @ParamSet
                            ForEach ($Item In $AddSubnet)
                            {
                                Write-Debug -Message "Create SubnetVlan Subnet: '$($Item.Subnet)' Name: '$($Item.Name)'."
                                $NewSubnet = New-SCSubnetVLan -Subnet $Item.Subnet -ErrorAction Stop
                                New-SCVMSubnet -Name $Item.Name -VMNetwork $vmNetwork -SubnetVLan $NewSubnet -ErrorAction Stop
                            }
                        }
                        Catch
                        {
                            If ($vmNetwork)
                            {
                                $remove = $vmNetwork | Remove-SCVMNetwork
                            }
                            Throw "$($_.Exception.Message)."
                        }
                    }
                }
                Else
                {
                    Write-Debug -Message "Logical Network is 'One Connected Network' type without Network Virtualization"
                    If ($ExistingVMNetworks.Count -ge 1)
                    {
                        throw New-TerminatingError -ErrorType NetworkVirtualizationRequiredMultiple
                    }
                    If ($IsolationVMNetworkProtocol -or $IsolationLogicalNetworkProtocol)
                    {
                        throw New-TerminatingError -ErrorType NetworkVirtualizationRequiredIsolation
                    }
                    If ($VMSubnets.Count -ge 1)
                    {
                        throw New-TerminatingError -ErrorType NetworkVirtualizationRequiredSubnet
                    }
                    If ($ThisVMNetwork)
                    {
                        Try
                        {
                            Write-Verbose -Message "Change VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
                            $vmNetwork = Set-SCVMNetwork -VMNetwork $ThisVMNetwork -Description $Description -ErrorAction Stop
                        }
                        Catch
                        {
                            Throw "$($_.Exception.Message)."
                        }
                    }
                    Else
                    {
                        Try
                        {
                            Write-Verbose -Message "Create new VM Network named '$($Name)' associated to Logical Network '$($LogicalNetwork)'."
                            $vmNetwork = New-SCVMNetwork -Name $Name -LogicalNetwork $ThisLogicalNetwork -IsolationType "NoIsolation" -Description $Description -ErrorAction Stop
                        }
                        Catch
                        {
                            If ($vmNetwork)
                            {
                                $remove = $vmNetwork | Remove-SCVMNetwork
                            }
                            Throw "$($_.Exception.Message)."
                        }
                    }
                }
            }
        }
        "Absent"
        {
            If ($ThisVMNetwork)
                {
                Remove-ThisVMNetwork
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
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",
        
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,
        
        [System.String]
        $Description,
        
        [Parameter(Mandatory = $true)]
        [System.String]
        $LogicalNetwork,
        
        [ValidateSet("IPv4","IPv6")]
        [System.String]
        $IsolationVMNetworkProtocol,
        
        [ValidateSet("IPv4","IPv6")]
        [System.String]
        $IsolationLogicalNetworkProtocol,
        
        [System.String[]]
        $VMSubnets,
        
        [System.Boolean]
        $AutoCreateSubnet,
        
        [System.String]
        $NetworkSite,
        
        [System.Boolean]
        $StrictConfiguration = $false
    )
    
    Test-Requirements
    Write-Verbose -Message "Validate VM Network named '$($Name)' on Logical Network '$($LogicalNetwork)'."
    [System.Boolean]$result = $true
    $CurrentConfig = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: VM Network named '$($Name)' is '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        If ($CurrentConfig.IsolationType -eq "VLANNetwork")
        {
            If ($VMSubnets.Count -gt 1)
            {
                $VMSubnets = $VMSubnets[0]
            }
            If ($IsolationVMNetworkProtocol)
            {
                Remove-Variable IsolationVMNetworkProtocol
            }
            If ($IsolationLogicalNetworkProtocol)
            {
                Remove-Variable IsolationLogicalNetworkProtocol
            }
        }
        If ($Description)
        {
            If ($CurrentConfig.Description -ne $Description)
            {
                Write-Verbose -Message "FAIL: Description is incorrect."
                $result = $false
            }
        }
        If ($IsolationVMNetworkProtocol)
        {
            If ($CurrentConfig.IsolationVMNetworkProtocol -ne $IsolationVMNetworkProtocol)
            {
                Write-Verbose -Message "FAIL: IsolationVMNetworkProtocol is incorrect."
                $result = $false
            }
        }
        If ($IsolationLogicalNetworkProtocol)
        {
            If ($CurrentConfig.IsolationLogicalNetworkProtocol -ne $IsolationLogicalNetworkProtocol)
            {
                Write-Verbose -Message "FAIL: IsolationLogicalNetworkProtocol is incorrect."
                $result = $false
            }
        }
        ForEach ($TestSubnet In $VMSubnets)
        {
            If ($CurrentConfig.VMSubnets -notcontains $TestSubnet)
            {
                Write-Verbose -Message "FAIL: VMSubnet '$($TestSubnet)' does not exist on this VM Network."
                $result = $false
            }
        }
        If (($StrictConfiguration) -and (-not $AutoCreateSubnet))
        {
            ForEach ($TestSubnet In $CurrentConfig.VMSubnets)
            {
                If ($VMSubnets -notcontains $TestSubnet)
                {
                    Write-Verbose -Message "FAIL: Found unspecified VMSubnet: '$($TestSubnet)' on this VM Network."
                    $result = $false
                }
            }
        }
    }
    Write-Debug -Message "Return from Test-TargetResource is '$($result)'."
    return $result
}

Export-ModuleMember -Function *-TargetResource
