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

function Test-IsValidAddress
{
    param
    (
        [System.String]$Address
    )
    If ([System.Net.IPAddress]::TryParse($Address,[ref]$null))
    {
        If ($Address -notmatch [System.Net.IPAddress]$Address)
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

Function IPv4-ToBinary
{
    param
    (
        [System.Net.IPAddress]$Address
    )
    [System.String]$DottedDecimal = $Address
    $DottedDecimal.Split(".") | ForEach-Object { $Binary = $Binary + $([Convert]::ToString($PSItem,2).PadLeft(8,"0"))}
    Return $Binary
}

Function IPv6-ToBinary
{
    param
    (
        [System.Net.IPAddress]$Address
    )
    $Address.GetAddressBytes() | ForEach-Object { $Binary += [Convert]::ToString($PSItem, 2).PadLeft(8,'0') }
    Return $Binary
}

Function Binary-ToIPv4
{
    param
    (
        [System.String]$Binary
    )
    Do
    {
        $DottedDecimal += "." + [System.String]$([Convert]::ToInt32($Binary.SubString($i,8),2))
        $i += 8
    } While ($i -le 24)
    Return $DottedDecimal.SubString(1)
}

Function Binary-ToIPv6
{
    param
    (
        [System.String]$Binary
    )
    Do
    {
        $Hex += ":" + ("{0:x}" -f ([Convert]::ToInt32($Binary.SubString($i,16),2))).ToUpper()
        $i += 16
    } While ($i -le 112)
    Return $Hex.SubString(1)
}

function Test-IsInSubnet
{
    param
    (
        [System.String]$Address
    )
    If ($IsIPv6)
    {
        [System.String]$Binary = IPv6-ToBinary $Address
    }
    Else
    {
        [System.String]$Binary = IPv4-ToBinary $Address
    }
    If ($($Binary.SubString(0,$NetMask).PadRight($MaxPrefix,"1")) -eq $BroadcastAddress)
    {
        Return $true
    }
    Else
    {
        Return $false
    }
}

function Test-LogicalNetwork
{
    $script:ThisNetwork = Get-SCLogicalNetwork -Name $SourceNetworkName
    If (-not $ThisNetwork)
    {
        throw New-TerminatingError -ErrorType LogicalNetworkNotFound -FormatArgs @($SourceNetworkName) -ErrorCategory ObjectNotFound
    }
    If ((Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisNetwork).Count -eq 0)
    {
        throw New-TerminatingError -ErrorType NoNetworkSitesFound -FormatArgs @($SourceNetworkName) -ErrorCategory ObjectNotFound -TargetObject $ThisNetwork
    }
    If ($SourceNetworkSite)
    {
        $script:ThisSite = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisNetwork -Name $SourceNetworkSite
        If (-not $ThisSite)
        {
            throw New-TerminatingError -ErrorType NetworkSiteNotFound -FormatArgs @($SourceNetworkSite, $SourceNetworkName) -ErrorCategory ObjectNotFound -TargetObject $ThisNetwork
        }
        If ($SourceNetworkSubnet)
        {
            $script:ThisSite = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisNetwork -Name $SourceNetworkSite -Subnet $SourceNetworkSubnet
        }
    }
    ElseIf ($SourceNetworkSubnet)
    {
        $script:ThisSite = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisNetwork -Subnet $SourceNetworkSubnet
    }
    Else
    {
        $script:ThisSite = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisNetwork
        If ($ThisSite.Count -gt 1)
        {
            $script:ThisSite = $ThisSite[0]
        }
    }
    If (-not $ThisSite)
    {
        throw New-TerminatingError -ErrorType NetworkSiteNotFound2 -FormatArgs @($SourceNetworkName) -ErrorCategory ObjectNotFound -TargetObject $ThisNetwork
    }
    If ($SourceNetworkSubnet)
    {
        $script:ThisPool = Get-SCStaticIPAddressPool -Name $Name -LogicalNetworkDefinition $ThisSite -Subnet $SourceNetworkSubnet
    }
    Else
    {
        $script:ThisPool = Get-SCStaticIPAddressPool -Name $Name -LogicalNetworkDefinition $ThisSite
    }
}

function Test-VMNetwork
{
    $script:ThisNetwork = Get-SCVMNetwork -Name $SourceNetworkName
    If (-not $ThisNetwork)
    {
        throw New-TerminatingError -ErrorType VMNetworkNotFound -FormatArgs @($SourceNetworkName) -ErrorCategory ObjectNotFound
    }
    If ($ThisNetwork.IsolationType -eq "VLANNetwork")
    {
        throw New-TerminatingError -ErrorType IsolationIPPoolMustUseLogicalNetwork
    }
    If ($ThisNetwork.IsolationType -eq "NoIsolation")
    {
        throw New-TerminatingError -ErrorType NoIsolationStaticIPPool
    }
    If ($SourceNetworkSite)
    {
        Write-Warning -Message "SourceNetworkSite should only be used with Logical Networks."
    }
    If ($SourceNetworkSubnet)
    {
        If ($ThisNetwork.Count -gt 1)
        {
            Get-SCVMNetwork | ForEach-Object `
            {
                If ($PSItem.VMSubnet.SubnetVlans.Subnet -eq $SourceNetworkSubnet)
                {
                    $script:ThisVMSubnet = $PSITem
                }
            }
        }
        Else
        {
            $script:ThisVMSubnet = Get-SCVMSubnet -VMNetwork $ThisNetwork -Subnet $SourceNetworkSubnet
        }
    }
    Else
    {
        If ($ThisNetwork.Count -gt 1)
        {
            $ThisNetwork = $ThisNetwork[0]
        }
        $script:ThisVMSubnet = Get-SCVMSubnet -VMNetwork $ThisNetwork
        If ($ThisVMSubnet.Count -gt 1)
        {
            $ThisVMSubnet = $ThisVMSubnet[0]
        }
    }
    If (-not $ThisVMSubnet)
    {
        throw New-TerminatingError -ErrorType SubnetNotFound -FormatArgs @($SourceNetworkName) -ErrorCategory ObjectNotFound
    }
    $script:ThisPool = Get-SCStaticIPAddressPool -Name $Name -VMSubnet $ThisVMSubnet
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name,
        
        [parameter(Mandatory = $true)]
        [System.String]$SourceNetworkName,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("LogicalNetwork","VMNetwork")]
        [System.String]$SourceNetworkType,
        
        [System.String]$SourceNetworkSite,
        
        [System.String]$SourceNetworkSubnet
    )
    
    Test-Requirements
    Switch ($SourceNetworkType)
    {
        "VMNetwork"
        {
            Test-VMNetwork
        }
        "LogicalNetwork"
        {
            Test-LogicalNetwork
        }
    }
    If ($ThisPool)
    {
        $Gateways = @()
        ForEach ($Item In $ThisPool.DefaultGateways)
        {
            [System.String]$FoundGw = ($Item.IPAddress)
            If ($Item.Metric)
            {
                $FoundGw += ';' + $Item.Metric
            }
            $Gateways += $FoundGw
            Write-Debug -Message "Found Gateway: '$($FoundGw)'."
        }
        $DnsServers = @()
        ForEach ($Item In $ThisPool.DNSServers)
        {
            $DnsServers += [System.String]$Item
        }
        $DNSSuffix = $ThisPool.DNSSuffix
        $DnsSearchSuffixes = @()
        ForEach ($Item In $ThisPool.DNSSearchSuffixes)
        {
            $DNSSearchSuffixes += [System.String]$Item
        }
        $WinsServers = @()
        ForEach ($Item In $ThisPool.WINSServers)
        {
            $WinsServers += [System.String]$Item
        }
        $VIPReservations = @()
        If ($ThisPool.VIPAddressSet)
        {
            If ($ThisPool.VIPAddressSet.Split(',').Count -gt 1)
            {
                ForEach ($Item In $ThisPool.VIPAddressSet.Split(',',[StringSplitOptions]'RemoveEmptyEntries').Trim())
                {
                    $VIPReservations += $Item
                    Write-Debug -Message "Found VIP Reservation: '$($Item)'."
                }
            }
            Else
            {
                $VIPReservations += $ThisPool.VIPAddressSet
                Write-Debug -Message "Found VIP Reservation: '$($ThisPool.VIPAddressSet)'."
            }
        }
        $OtherReservations = @()
        If ($ThisPool.IPAddressReservedSet)
        {
            If ($ThisPool.IPAddressReservedSet.Split(',').Count -gt 1)
            {
                ForEach ($Item In ($ThisPool.IPAddressReservedSet).Split(',',[StringSplitOptions]'RemoveEmptyEntries').Trim())
                {
                    $OtherReservations += $Item
                    Write-Debug -Message "Found IP Reservation: '$($Item)'."
                }
            }
            Else
            {
                $OtherReservations += $ThisPool.IPAddressReservedSet
                Write-Debug -Message "Found IP Reservation: '$($ThisPool.IPAddressReservedSet)'."
            }
        }
        [System.String]$Ensure = "Present"
        [System.String]$Name = $ThisPool.Name
        [System.String]$Description = $ThisPool.Description
        [System.String]$IPAddressRange = $ThisPool.IPAddressRangeStart + "-" + $ThisPool.IPAddressRangeEnd
        [System.String[]]$Gateway = $Gateways
        [System.String[]]$DnsServer = $DnsServers
        [System.String]$DnsSuffix = $DnsSuffix
        [System.String[]]$DnsSearchSuffix = $DnsSearchSuffixes
        [System.String[]]$WinsServer = $WinsServers
        [System.Boolean]$NetBIOSOverTCPIP = $ThisPool.EnableNetBIOS
        [System.String[]]$VIPReservation = $VIPReservations
        [System.String[]]$OtherReservation = $OtherReservations
    }
    Else
    {
        [System.String]$Ensure = "Absent"
        [System.String]$Name = $Name 
        [System.String]$Description = ""
        [System.String]$IPAddressRange = ""
        [System.String[]]$Gateway = @()
        [System.String[]]$DnsServer = @()
        [System.String]$DnsSuffix = ""
        [System.String[]]$DnsSearchSuffix = @()
        [System.String[]]$WinsServer = @()
        [System.Boolean]$NetBIOSOverTCPIP = $false
        [System.String[]]$VIPReservation = @()
        [System.String[]]$OtherReservation = @()
    }
    $returnValue = @{
        Ensure = $Ensure
        Name = $Name
        Description = $Description
        IPAddressRange = $IPAddressRange
        Gateway = $Gateway
        DnsServer = $DnsServer
        DnsSuffix = $DnsSuffix
        DnsSearchSuffix = $DnsSearchSuffix
        WinsServer = $WinsServer
        NetBIOSOverTCPIP = $NetBIOSOverTCPIP
        VIPReservation = $VIPReservation
        OtherReservation = $OtherReservation
    }
    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure = "Present",
        
        [parameter(Mandatory = $true)]
        [System.String]$Name,
        
        [System.String]$Description,
        
        [parameter(Mandatory = $true)]
        [System.String]$SourceNetworkName,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("LogicalNetwork","VMNetwork")]
        [System.String]$SourceNetworkType,
        
        [System.String]$SourceNetworkSite,
        
        [System.String]$SourceNetworkSubnet,
        
        [System.String]$IPAddressRange,
        
        [System.String[]]$Gateway,
        
        [System.String[]]$DnsServer,
        
        [System.String]$DnsSuffix,
        
        [System.String[]]$DnsSearchSuffix,
        
        [System.String[]]$WinsServer,
        
        [System.Boolean]$NetBIOSOverTCPIP,
        
        [System.String[]]$VIPReservation,
        
        [System.String[]]$OtherReservation
    )
    
    Test-Requirements
    Switch ($SourceNetworkType)
    {
        "VMNetwork"
        {
            Test-VMNetwork
        }
        "LogicalNetwork"
        {
            Test-LogicalNetwork
        }
    }
    Switch ($Ensure)
    {
        "Present"
        {
            If (-not $Description)
            {
                $Description = "$Name - DSC created Static IP Pool"
            }
            $ParamSet = `
            @{
                Name = $Name
                Description = $Description
                RunAsynchronously = $true
                ErrorAction = "Stop"
            }
            Switch ($SourceNetworkType)
            {
                "VMNetwork"
                {
                    If ($ThisPool)
                    {
                        $ParamSet += @{StaticIPAddressPool = $ThisPool}
                        [System.String]$script:Subnet = $ThisPool.Subnet
                    }
                    Else
                    {
                        $ParamSet += @{VMSubnet = $ThisVMSubnet}
                        [System.String]$script:Subnet = $ThisVMSubnet.SubnetVLans.Subnet
                        $ParamSet += @{Subnet = $Subnet}
                        If ($Gateway.Count -ne 0)
                        {
                            Write-Warning "On a VM Network the default gateway will automatically be set to the first address in the subnet."
                            $Gateway = @()
                        }
                    }
                }
                "LogicalNetwork"
                {
                    If ($ThisPool)
                    {
                        $ParamSet += @{StaticIPAddressPool = $ThisPool}
                        [System.String]$script:Subnet = $ThisPool.Subnet
                    }
                    Else
                    {
                        $ParamSet += @{LogicalNetworkDefinition = $ThisSite}
                        If ($SourceNetworkSubnet)
                        {
                            [System.String]$script:Subnet = $SourceNetworkSubnet
                        }
                        Else
                        {
                            If ($ThisSite.SubnetVLans.Subnet.Count -gt 1)
                            {
                                [System.String]$script:Subnet = $ThisSite.SubnetVLans.Subnet[0]
                            }
                            Else
                            {
                               [System.String]$script:Subnet = $ThisSite.SubnetVLans.Subnet
                            }
                        }
                        $ParamSet += @{Subnet = $Subnet}
                    }
                }
            }

            If (-not $Subnet)
            {
                throw New-TerminatingError -ErrorType SubnetUndetermined
            }

            [System.Net.IPAddress]$SubnetIP = $Subnet.Split('/')[0]
            [Int32]$script:NetMask = $Subnet.Split('/')[1]
            If ($SubnetIP.AddressFamily -eq 'InterNetworkV6')
            {
                $script:IsIPv6 = $true
                $script:MaxPrefix = 128
                $script:MinPrefix = 16
                $IpBinary = IPv6-ToBinary $SubnetIP
            }
            Else
            {
                $script:IsIPv6 = $false
                $script:MaxPrefix = 32
                $script:MinPrefix = 1
                $IpBinary = IPv4-ToBinary $SubnetIP
            }
            $script:BroadcastAddress = $($IpBinary.SubString(0,$NetMask).PadRight($MaxPrefix,"1"))
            If ($IPAddressRange)
            {
                If ($IPAddressRange.Split('-').Count -ne 2)
                {
                    throw New-TerminatingError -ErrorType SubnetUndetermined -TargetObject $IPAddressRange
                }
                $BegIP = $IPAddressRange.Split('-')[0]
                $EndIP = $IPAddressRange.Split('-')[1]
                If (-not (Test-IsValidAddress $BegIP))
                {
                    throw New-TerminatingError -ErrorType InvalidStartIPRange -FormatArgs @($BegIP) -TargetObject $BegIP
                }
                If (-not (Test-IsValidAddress $EndIP))
                {
                    throw New-TerminatingError -ErrorType InvalidEndIPRange -FormatArgs @($EndIP) -TargetObject $EndIP
                }
                If (-not (Test-IsInSubnet $BegIP))
                {
                    throw New-TerminatingError -ErrorType StartIPNotInSubnet -FormatArgs @($BegIP, $Subnet) -TargetObject $BegIP
                }
                If (-not (Test-IsInSubnet $EndIP))
                {
                    throw New-TerminatingError -ErrorType EndIPNotInSubnet -FormatArgs @($EndIP, $Subnet) -TargetObject $EndIP
                }
                If ($SourceNetworkType -eq "VMNetwork")
                {
                    $GatewayAddress = $($IpBinary.SubString(0,$NetMask).PadRight(($MaxPrefix-1),"0") + "1")
                    If ($IsIPv6)
                    {
                        $GatewayIP = Binary-ToIPv6 $GatewayAddress
                    }
                    Else
                    {
                        $GatewayIP = Binary-ToIPv4 $GatewayAddress
                    }
                    $Gateway = @($GatewayIP)
                    If ($BegIP -eq $GatewayIP)
                    {
                        throw New-TerminatingError -ErrorType FirstIPIsGateway -TargetObject $BegIP
                    }
                }
            }
            Else
            {
                Write-Verbose -Message "IPAddressRange not specified, automatically using the entire subnet range from the subnet '$($Subnet)'."
                If ($SourceNetworkType -eq "VMNetwork")
                {
                    $GatewayAddress = $($IpBinary.SubString(0,$NetMask).PadRight(($MaxPrefix-1),"0") + "1")
                    $FirstAddress = $($IpBinary.SubString(0,$NetMask).PadRight(($MaxPrefix-2),"0") + "10")
                }
                Else
                {
                    $FirstAddress = $($IpBinary.SubString(0,$NetMask).PadRight(($MaxPrefix-1),"0") + "1")
                }
                $LastAddress = $($IpBinary.SubString(0,$NetMask).PadRight(($MaxPrefix-1),"1") + "0")
                If ($IsIPv6)
                {
                    $BegIP = Binary-ToIPv6 $FirstAddress
                    $EndIP = Binary-ToIPv6 $LastAddress
                    If ($GatewayAddress)
                    {
                        $GatewayIP = Binary-ToIPv6 $GatewayAddress
                        $Gateway = @($GatewayIP)
                    }
                }
                Else
                {
                    $BegIP = Binary-ToIPv4 $FirstAddress
                    $EndIP = Binary-ToIPv4 $LastAddress
                    If ($GatewayAddress)
                    {
                        $GatewayIP = Binary-ToIPv4 $GatewayAddress
                        $Gateway = @($GatewayIP)
                    }
                }
            }
            Write-Verbose -Message "The IP Address range for this pool will be: '$($BegIP)' to '$($EndIP)'."
            $ParamSet += @{IPAddressRangeStart = $BegIP;IPAddressRangeEnd = $EndIP}
            
            $allGateways = @()            
            If ($Gateway.Count -gt 0)
            {
                ForEach ($Item In $Gateway)
                {
                    $Address = $Item.Split(';')[0]
                    If (-not (Test-IsValidAddress $Address))
                    {
                        throw New-TerminatingError -ErrorType InvalidGatewayIP -FormatArgs @($Address) -TargetObject $Address
                    }
                    If (-not (Test-IsInSubnet $Address))
                    {
                        throw New-TerminatingError -ErrorType GatewayNotInSubnet -FormatArgs @($Address, $Subnet) -TargetObject $Address
                    }
                    If ($Item.Split(';').Count -gt 1)
                    {
                        $Metric = $Item.Split(';')[1]
                        If ($Metric)
                        {
                            $ValidMetric = $true
                            If ([Int32]::TryParse($Metric,[Ref]$null))
                            {
                                If (-not(([Int]$Metric -ge 1) -and ([Int]$Metric -le 9999)))
                                {
                                    $ValidMetric = $false
                                }
                            }
                            Else
                            {
                                $ValidMetric = $false
                            }
                            If (-not $ValidMetric)
                            {
                                throw New-TerminatingError -ErrorType InvalidGatewayMetric
                            }
                            Write-Debug -Message "Adding Gateway - Address: '$($Address)' Metric: '$($Metric)'."
                            $allGateways += New-SCDefaultGateway -IPAddress $Address -Metric $Metric
                        }
                        Else
                        {
                            Write-Debug -Message "Adding Gateway - Address: '$($Address)' Metric: 'Automatic'."
                            $allGateways += New-SCDefaultGateway -IPAddress $Address -Automatic
                        }
                    }
                    Else
                    {
                        Write-Debug -Message "Adding Gateway - Address: '$($Address)' Metric: 'Automatic'."
                        $allGateways += New-SCDefaultGateway -IPAddress $Address -Automatic
                    }
                }
                If ($allGateways.Count -gt 0)
                {
                    $ParamSet += @{DefaultGateway = $allGateways}
                }
            }
            
            If ($DnsServer)
            {
                $allDnsServer = @()
                ForEach ($Item In $DnsServer)
                {
                    If (-not (Test-IsValidAddress $Item))
                    {
                        throw New-TerminatingError -ErrorType InvalidDNSIP -FormatArgs @($Item) -TargetObject $Item
                    }
                    $allDnsServer += $Item
                }
                If ($allDnsServer.Count -gt 0)
                {
                    $ParamSet += @{DNSServer = $allDnsServer}
                }
            }
            
            If ($DnsSuffix)
            {
                $ParamSet += @{DNSSuffix = $DnsSuffix}
            }
            
            $allDnsSuffixes = @()
            ForEach ($Item In $DnsSearchSuffix)
            {
                $allDnsSuffixes += $Item
            }
            If ($allDnsSuffixes.Count -gt 0)
            {
                $ParamSet += @{DNSSearchSuffix = $allDnsSuffixes}
            }
            
            If ($WinsServer)
            {
                $allWinsServers = @()
                ForEach ($Item In $WinsServer)
                {
                    If (-not (Test-IsValidAddress $Item))
                    {
                        throw New-TerminatingError -ErrorType InvalidWINSIP -FormatArgs @($Item) -TargetObject $Item
                    }
                    $allWinsServers += $Item
                }
                If ($allWinsServers.Count -gt 0)
                {
                    $ParamSet += @{WINSServer = $allWinsServers}
                    If ($NetBIOSOverTCPIP)
                    {
                        $ParamSet += @{EnableNetBIOS = $true}
                    }
                    Else
                    {
                        $ParamSet += @{EnableNetBIOS = $false}
                    }
                }
            }
            
            [System.String]$VIPAddressSet = ""
            If ($VIPReservation)
            {
                ForEach ($Item In $VIPReservation.Split(','))
                {
                    If ($Item.Split('-').Count -gt 1)
                    {
                        $BegVIP = $Item.Split('-')[0]
                        $EndVIP = $Item.Split('-')[1]
                        If (-not (Test-IsInSubnet $BegVIP))
                        {
                            throw New-TerminatingError -ErrorType VIPStartIPNotInSubnet -FormatArgs @($BegVIP, $Subnet) -TargetObject $BegVIP
                        }
                        If (-not (Test-IsInSubnet $EndVIP))
                        {
                            throw New-TerminatingError -ErrorType VIPEndIPNotInSubnet -FormatArgs @($EndVIP, $Subnet) -TargetObject $EndVIP
                        }
                        $VIPAddressSet += ($BegVIP + '-' + $EndVIP + ',')
                    }
                    Else
                    {
                        If (-not (Test-IsInSubnet $Item))
                        {
                            throw New-TerminatingError -ErrorType VIPIPNotInSubnet -FormatArgs @($Item, $Subnet) -TargetObject $Item
                        }
                        $VIPAddressSet += ($Item + ',')
                    }
                }
                If ($VIPAddressSet)
                {
                    If ($VIPAddressSet.EndsWith(','))
                    {
                        $VIPAddressSet = $VIPAddressSet.SubString(0,($VIPAddressSet.Length-1))
                    }
                    $ParamSet += @{VIPAddressSet = $VIPAddressSet}
                }
            }
            
            [System.String]$IPAddressReservedSet = ""
            If ($OtherReservation)
            {
                ForEach ($Item In $OtherReservation.Split(','))
                {
                    If ($Item.Split('-').Count -gt 1)
                    {
                        $BegRIP = $Item.Split('-')[0]
                        $EndRIP = $Item.Split('-')[1]
                        If (-not (Test-IsInSubnet $BegRIP))
                        {
                            throw New-TerminatingError -ErrorType ResStartIPNotInSubnet -FormatArgs @($BegRIP, $Subnet) -TargetObject $BegRIP
                        }
                        If (-not (Test-IsInSubnet $EndRIP))
                        {
                            throw New-TerminatingError -ErrorType ResEndIPNotInSubnet -FormatArgs @($EndRIP, $Subnet) -TargetObject $EndRIP
                        }
                        $IPAddressReservedSet += ($BegRIP + '-' + $EndRIP + ',')
                    }
                    Else
                    {
                        If (-not (Test-IsInSubnet $Item))
                        {
                            throw New-TerminatingError -ErrorType ResIPNotInSubnet -FormatArgs @($Item, $Subnet) -TargetObject $Item
                        }
                        $IPAddressReservedSet += ($Item + ',')
                    }
                }
                If ($IPAddressReservedSet)
                {
                    If ($IPAddressReservedSet.EndsWith(','))
                    {
                        $IPAddressReservedSet = $IPAddressReservedSet.SubString(0,($IPAddressReservedSet.Length-1))
                    }
                    $ParamSet += @{IPAddressReservedSet = $IPAddressReservedSet}
                }
            }
            
            $ParamSet.Keys | % { Write-Debug -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
            Try
            {
                If ($ThisPool)
                {
                    Write-Verbose -Message "Change existing Static IP Address Pool"
                    Set-SCStaticIPAddressPool @ParamSet
                }
                Else
                {
                    Write-Verbose -Message "Create new Static IP Address Pool"
                    New-SCStaticIPAddressPool @ParamSet
                }
            }
            Catch
            {
                Throw $PSItem.Exception
            }
        }
        "Absent"
        {
            If ($ThisPool)
            {
                Try
                {
                    Write-Verbose -Message "Remove the Static IP Address Pool named '$($Name)'."
                    $RevokeIPs = Get-SCIPAddress -StaticIPAddressPool $ThisPool | Revoke-SCIPAddress
                    $DeletePool = $ThisPool | Remove-SCStaticIPAddressPool -Confirm:$false
                }
                Catch
                {
                    Throw $PSItem.Exception
                }
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
        [System.String]$Ensure = "Present",
        
        [parameter(Mandatory = $true)]
        [System.String]$Name,
        
        [System.String]$Description,
        
        [parameter(Mandatory = $true)]
        [System.String]$SourceNetworkName,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("LogicalNetwork","VMNetwork")]
        [System.String]$SourceNetworkType,
        
        [System.String]$SourceNetworkSite,
        
        [System.String]$SourceNetworkSubnet,
        
        [System.String]$IPAddressRange,
        
        [System.String[]]$Gateway,
        
        [System.String[]]$DnsServer,
        
        [System.String]$DnsSuffix,
        
        [System.String[]]$DnsSearchSuffix,
        
        [System.String[]]$WinsServer,
        
        [System.Boolean]$NetBIOSOverTCPIP,
        
        [System.String[]]$VIPReservation,
        
        [System.String[]]$OtherReservation
    )
    
    Test-Requirements
    Write-Verbose -Message "Validate Static IP Pool named '$($Name)' on $($SourceNetworkType) '$($SourceNetworkName)'."
    [System.Boolean]$result = $true
    $ParamSet = `
    @{
        Name = $Name
        SourceNetworkType = $SourceNetworkType
        SourceNetworkName = $SourceNetworkName
    }
    If ($SourceNetworkSite)
    {
        $ParamSet += @{ SourceNetworkSite = $SourceNetworkSite }
    }
    If ($SourceNetworkSubnet)
    {
        $ParamSet += @{ SourceNetworkSubnet = $SourceNetworkSubnet }
    }
    $CurrentConfig = Get-TargetResource @ParamSet
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: '$($Name)' is '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        If ($Description)
        {
            If ($CurrentConfig.Description -ne $Description)
            {
                Write-Verbose -Message "FAIL: Description is incorrect."
                $result = $false
            }
        }
        If ($IPAddressRange)
        {
            If ($CurrentConfig.IPAddressRange -ne $IPAddressRange)
            {
                Write-Verbose -Message "FAIL: IP Address range '$($CurrentConfig.IPAddressRange)' does not match expected '$($IPAddressRange)'."
                $result = $false
            }
        }
        If ($SourceNetworkType -eq "LogicalNetwork")
        {
            ForEach ($Item In $Gateway)
            {
                If ($CurrentConfig.Gateway -notcontains $Item)
                {
                    Write-Verbose -Message "FAIL: Missing gateway '$($Item)'."
                    $result = $false
                }
            }
        }
        ForEach ($Item In $DnsServer)
        {
            If ($CurrentConfig.DnsServer -notcontains $Item)
            {
                Write-Verbose -Message "FAIL: Missing DNS Server '$($Item)'."
                $result = $false
            }
        }
        If ($CurrentConfig.DnsSuffix -ne $DnsSuffix)
        {
            Write-Verbose -Message "FAIL: DNS Suffix does not match."
            $result = $false
        }
        ForEach ($Item In $DnsSearchSuffix)
        {
            If ($CurrentConfig.DnsSearchSuffix -notcontains $Item)
            {
                Write-Verbose -Message "FAIL: Missing DNS Search Suffix '$($Item)'."
                $result = $false
            }
        }
        ForEach ($Item In $WinsServer)
        {
            If ($CurrentConfig.WinsServer -notcontains $Item)
            {
                Write-Verbose -Message "FAIL: Missing WINS Server '$($Item)'."
                $result = $false
            }
        }
        If ($CurrentConfig.NetBIOSOverTCPIP -ne $NetBIOSOverTCPIP)
        {
            Write-Verbose -Message "FAIL: NetBIOS over TCP/IP setting is incorrect."
            $result = $false
        }
        ForEach ($Item In $VIPReservation)
        {
            If ($CurrentConfig.VIPReservation -notcontains $Item)
            {
                Write-Verbose -Message "FAIL: Missing VIP Reservation '$($Item)'."
                $result = $false
            }
        }
        ForEach ($Item In $OtherReservation)
        {
            If ($CurrentConfig.OtherReservation -notcontains $Item)
            {
                Write-Verbose -Message "FAIL: Missing IP Reservation '$($Item)'."
                $result = $false
            }
        }
    }
	return $result
}

Export-ModuleMember -Function *-TargetResource
