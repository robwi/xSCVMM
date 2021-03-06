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

function Test-IsValidSubnet
{
    param
    (
        [string]$Subnet
    )
    
    If ($Subnet.Split('/').Count -ne 2)
    {
        return $false
    }
    Else
    {
        [string]$SubnetAddress = $Subnet.Split('/')[0]
        [string]$SubnetPrefix = $Subnet.Split('/')[1]
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
        [string]$VlanId
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
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,
        
        [parameter(Mandatory = $true)]
        [System.String]
        $LogicalNetwork
    )

    Test-Requirements
    $ThisLogicalNetwork = Get-SCLogicalNetwork -Name $LogicalNetwork -VMMServer $env:COMPUTERNAME
    If ($ThisLogicalNetwork)
    {
        $LogicalNetworkDef = Get-SCLogicalNetworkDefinition -VMMServer $env:COMPUTERNAME -LogicalNetwork $ThisLogicalNetwork -Name $Name
        If ($LogicalNetworkDef)
        {
            $Ensure = "Present"
            [System.Array]$HostGroups = @()
            ForEach ($Group In $LogicalNetworkDef.HostGroups)
            {
                $HostGroups += [string]$Group.Name
            }
            [System.Array]$SubnetVlan = @()
            ForEach ($Site In $LogicalNetworkDef.SubnetVLans)
            {
                [string]$AddSite = $Site.Subnet + "-" + $Site.VLanID + "-" + $Site.SecondaryVLanID
                $SubnetVlan += $AddSite
            }
        }
        Else
        {
            $Ensure = "Absent"
            $HostGroups = $null
            $SubnetVlan = $null
        }
    }
    Else
    {
        Write-Warning -Message "The Logical Network named '$($LogicalNetwork)' could not be found."
        $Ensure = "Absent"
        $HostGroups = $null
        $SubnetVlan = $null
    }
    $returnValue = `
    @{
        Ensure = $Ensure
        Name = $Name
        HostGroups = $HostGroups
        SubnetVlan = $SubnetVlan
    }
    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $false)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $LogicalNetwork,

        [parameter(Mandatory = $false)]
        [System.String[]]
        $HostGroups = @("All Hosts"),

        [parameter(Mandatory = $false)]
        [System.String[]]
        $SubnetVlan,
        
        [parameter(Mandatory = $false)]
        [System.Boolean]
        $StrictConfiguration = $false
    )

    Test-Requirements
    $ThisLogicalNetwork = Get-SCLogicalNetwork -Name $LogicalNetwork -VMMServer $env:COMPUTERNAME
    If (-not $ThisLogicalNetwork)
    {
        throw New-TerminatingError -ErrorType LogicalNetworkNotFound -FormatArgs @($LogicalNetwork) -ErrorCategory ObjectNotFound
    }
    Switch ($Ensure)
    {
        "Present"
        {
            $LogicalNetworkDef = Get-SCLogicalNetworkDefinition -VMMServer $env:COMPUTERNAME -LogicalNetwork $ThisLogicalNetwork -Name $Name
            [System.Array]$SetHostGroups = @()
            [System.Array]$RemoveHostGroups = @()
            [System.Array]$SetSubnetVlan = @()
            [System.Array]$ExistingGroups = @()
            [System.Array]$ExistingSubnetVlans = @()
            
            If ($LogicalNetworkDef)
            {
                $ExistingGroups = $LogicalNetworkDef.HostGroups.Name
                $ExistingSubnetVlans = $LogicalNetworkDef.SubnetVlans
            }
            
            ForEach ($Group In $HostGroups)
            {
                If ($ExistingGroups -notcontains $Group)
                {
                    $AddHostGroup = Get-SCVMHostGroup -Name $Group
                    If ($AddHostGroup)
                    {
                        Write-Debug -Message "SetHostGroups - Add '$($Group)'"
                        $SetHostGroups += $AddHostGroup
                    }
                    Else
                    {
                        throw New-TerminatingError -ErrorType HostGroupNotFound -FormatArgs @($Group) -ErrorCategory ObjectNotFound
                    }
                }
            }
            
            If ($StrictConfiguration)
            {
                ForEach ($Group In $ExistingGroups)
                {
                    If ($HostGroups -notcontains $Group)
                    {
                        $DelHostGroup = Get-SCVMHostGroup -Name $Group
                        If ($DelHostGroup)
                        {
                            Write-Debug -Message "RemoveHostGroups - Add '$($Group)'"
                            $RemoveHostGroups += $DelHostGroup
                        }
                    }
                }
            }
                
            ForEach ($Network In $SubnetVlan)
            {
                [string]$Subnet = $Network.Split('-')[0]
                [string]$VlanId = '0'
                [string]$SecondaryVlanId = '0'
                If ($Network.Split('-').Count -gt 1)
                {
                    $VlanId = $Network.Split('-')[1]
                    If ($VlanId -eq $null)
                    {
                        $VlanId = '0'
                    }
                    If ($ThisLogicalNetwork.IsPVLAN)
                    {
                        If ($Network.Split('-').Count -gt 2)
                        {
                            $SecondaryVlanId = $Network.Split('-')[2]
                            If (($SecondaryVlanId -eq $null) -or ($SecondaryVlanId -eq '0'))
                            {
                                throw New-TerminatingError -ErrorType SecondaryVlanNotFound -ErrorCategory ObjectNotFound -TargetObject $Network
                            }
                            If ($VlanId -eq $SecondaryVlanId)
                            {
                                throw New-TerminatingError -ErrorType SecondaryVlanMustBeDifferent -FormatArgs @($SecondaryVlanId) -ErrorCategory ObjectNotFound -TargetObject $Network
                            }
                        }
                        Else
                        {
                            throw New-TerminatingError -ErrorType SecondaryVlanNotFound -ErrorCategory ObjectNotFound
                        }
                    }
                }
                If (-not (Test-IsValidSubnet $Subnet))
                {
                    throw New-TerminatingError -ErrorType InvalidSubnet -FormatArgs @($Subnet) -TargetObject $Subnet
                }
                If (-not (Test-IsValidVlan $VlanId))
                {
                    throw New-TerminatingError -ErrorType InvalidVlan -FormatArgs @($VlanId) -TargetObject $VlanId
                }
                If (-not (Test-IsValidVlan $SecondaryVlanId))
                {
                    throw New-TerminatingError -ErrorType InvalidSecondVlan -FormatArgs @($SecondaryVlanId) -TargetObject $SecondaryVlanId
                }
                
                Write-Debug -Message "SetSubnetVlan - Add Subnet: '$($Subnet)', VlanId: '$($VlanId)', SecondaryVlanId: '$($SecondaryVlanId)'"
                If ($SecondaryVlanId -ne '0')
                {
                    $SetSubnetVlan += New-SCSubnetVLan -Subnet $Subnet -VLanID $VlanId -SecondaryVLanID $SecondaryVlanId
                }
                Else
                {
                    $SetSubnetVlan += New-SCSubnetVLan -Subnet $Subnet -VLanID $VlanId
                }
            }
            
            If (-not $StrictConfiguration)
            {
                ForEach ($Network In $ExistingSubnetVlans)
                {
                    If ($SetSubnetVlan.Subnet -notcontains $Network.Subnet)
                    {
                        Write-Debug -Message "SetSubnetVlan - Add Existing Subnet: '$($Network.Subnet)', VlanId: '$($Network.VLanID)', SecondaryVlanId: '$($Network.SecondaryVLanID)'"
                        If ($Network.SecondaryVLanID -ne '0')
                        {
                            $SetSubnetVlan += New-SCSubnetVLan -Subnet $Network.Subnet -VLanID $Network.VLanID -SecondaryVLanID $Network.SecondaryVLanID
                        }
                        Else
                        {
                            $SetSubnetVlan += New-SCSubnetVLan -Subnet $Network.Subnet -VLanID $Network.VLanID
                        }
                    }
                }
            }
            
            If ($LogicalNetworkDef)
            {
                $ParamSet = `
                @{
                    VMMServer = $env:COMPUTERNAME
                    Name = $Name
                    LogicalNetworkDefinition = $LogicalNetworkDef
                    SubnetVLan = $SetSubnetVlan
                    RunAsynchronously = $true
                    ErrorAction = 'Stop'
                }
                If ($SetHostGroups.Count -gt 0)
                {
                    $ParamSet += @{ AddVMHostGroup = $SetHostGroups }
                }
                If ($RemoveHostGroups.Count -gt 0)
                {
                    $ParamSet += @{ RemoveVMHostGroup = $RemoveHostGroups }
                }
                Write-Verbose -Message "Change settings of Logical Network Definition named '$($Name)' for Logical Network '$($ThisLogicalNetwork.Name)'."
                $ParamSet.Keys | % { Write-Debug -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
                Try
                {
                    Set-SCLogicalNetworkDefinition @ParamSet
                }
                Catch
                {
                    Throw $PSItem.Exception
                }
            }
            Else
            {
                $ParamSet = `
                @{
                    VMMServer = $env:COMPUTERNAME
                    Name = $Name
                    LogicalNetwork = $ThisLogicalNetwork
                    VMHostGroup = $SetHostGroups
                    SubnetVLan = $SetSubnetVlan
                    RunAsynchronously = $true
                    ErrorAction = 'Stop'
                }
                Write-Verbose -Message "Create Logical Network Definition named '$($Name)' for Logical Network '$($ThisLogicalNetwork.Name)'."
                $ParamSet.Keys | % { Write-Debug -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
                Try
                {
                    New-SCLogicalNetworkDefinition @ParamSet
                }
                Catch
                {
                    Throw $PSItem.Exception
                }
            }
        }
        "Absent"
        {
            $LogicalNetworkDefinition = Get-SCLogicalNetworkDefinition -LogicalNetwork $ThisLogicalNetwork -Name $Name
            If ($LogicalNetworkDefinition)
            {
                Try
                {
                    $StaticIPAddressPools = Get-SCStaticIPAddressPool -LogicalNetworkDefinition $LogicalNetworkDefinition -ErrorAction Stop
                    If ($StaticIPAddressPools.Count -gt 0)
                    {
                        Write-Verbose -Message "Removing Static IP Address Pools associated with this Logical Network Definition."
                        $StaticIPAddressPools | ForEach-Object `
                        {
                            Remove-SCStaticIPAddressPool $PSItem
                        }
                    }
                    Write-Verbose -Message "Remove Logical Network Definition named '$($Name)' from Logical Network '$($ThisLogicalNetwork.Name)'."
                    Remove-SCLogicalNetworkDefinition -LogicalNetworkDefinition $LogicalNetworkDefinition -ErrorAction Stop
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
        [parameter(Mandatory = $false)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $LogicalNetwork,

        [parameter(Mandatory = $false)]
        [System.String[]]
        $HostGroups = @("All Hosts"),

        [parameter(Mandatory = $false)]
        [System.String[]]
        $SubnetVlan,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $StrictConfiguration = $false
    )

    Test-Requirements
    Write-Verbose -Message "Validate Logical Network Definition named '$($Name)' for Logical Network '$($LogicalNetwork)'."
    [System.Boolean]$result = $true
    $CurrentConfig = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: '$($Name)' is '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        If ($StrictConfiguration)
        {
            If ($HostGroups.Count -ne $CurrentConfig.HostGroups.Count)
            {
                Write-Verbose -Message "FAIL: The number of HostGroups found was '$($CurrentConfig.HostGroups.Count)' when '$($HostGroups.Count)' was expected."
                $result = $false
            }
            If ($SubnetVlan.Count -ne $CurrentConfig.SubnetVlan.Count)
            {
                Write-Verbose -Message "FAIL: The number of Subnet/Vlans found was '$($CurrentConfig.SubnetVlan.Count)' when '$($SubnetVlan.Count)' was expected."
                $result = $false
            }
        }
        ForEach ($Group In $HostGroups)
        {
            If ($CurrentConfig.HostGroups -notcontains $Group)
            {
                Write-Verbose -Message "FAIL: Network Site does not contain the HostGroup '$($Group)'."
                $result = $false
            }
        }
        ForEach ($Site In $SubnetVlan)
        {
            [string]$Subnet = $Site.Split('-')[0]
            [string]$VlanId = '0'
            [string]$SecondaryVlanId = '0'
            If ($Site.Split('-').Count -gt 1)
            {
                $VlanId = $Site.Split('-')[1]
                If ($VlanId -eq $null)
                {
                    $VlanId = '0'
                }
            }
            If ($Site.Split('-').Count -gt 2)
            {
                $SecondaryVlanId = $Site.Split('-')[2]
                If ($SecondaryVlanId -eq $null)
                {
                    $SecondaryVlanId = '0'
                }
            }
            Write-Verbose -Message "Validate Network Site contains Subnet: '$($Subnet)', VlanId: '$($VlanId)', SecondaryVlanId: '$($SecondaryVlanId)'."
            $SiteFound = $false
            ForEach ($Network In $CurrentConfig.SubnetVlan)
            {
                If ($Network.Split("-")[0] -eq $Subnet)
                {
                    $SiteFound = $true
                    If ($Network.Split("-")[1] -ne $VlanId)
                    {
                        Write-Verbose -Message "FAIL: VlanId is '$($Network.Split("-")[1])' when it should be '$($VlanId)'."
                        $result = $false
                    }
                    If ($Network.Split("-")[2] -ne $SecondaryVlanId)
                    {
                        Write-Verbose -Message "FAIL: SecondaryVlanId is '$($Network.Split("-")[2])' when it should be '$($SecondaryVlanId)'."
                        $result = $false
                    }
                }
            }
            If (-not $SiteFound)
            {
                Write-Verbose -Message "FAIL: The definition does not contain a Network Site with the Subnet '$($Subnet)'."
                $result = $false
            }
        }
    }
    return $result
}

Export-ModuleMember -Function *-TargetResource
