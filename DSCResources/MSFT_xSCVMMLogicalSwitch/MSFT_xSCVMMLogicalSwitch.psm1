$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Verbose -Message "CurrentPath: $currentPath"

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

function Check-AbleToRemove
{
    param($LogicalSwitch)

    $AbleToRemove = $true
    $DependentHost = 0
    $DependentVM = 0
    $DependentPCF = 0
    ForEach ($vmhost In @(Get-SCVMHost))
    {
        $hostNics = Get-SCVMHostNetworkAdapter -VMHost $vmhost
        $uppNics = @($hostNics | Where-Object { $PSItem.UplinkPortProfileSet -ne $null } | Where-Object  { $PSItem.UplinkPortProfileSet.LogicalSwitch -eq $LogicalSwitch })
        $vNetNics = @($hostNics | Where-Object { $PSItem.VirtualNetwork -ne $null } | Where-Object { $PSItem.VirtualNetwork.LogicalSwitch -eq $LogicalSwitch })
        If (($uppNics.Count -gt 0) -or ($vNetNics.Count -gt 0))
        {
            $DependentHost++
        }
    }
    ForEach ($vm In @(Get-SCVirtualMachine -All))
    {
        $vnics = Get-SCVirtualNetworkAdapter -VM $vm | Where-Object {$PSItem.VirtualNetworkAdapterPortProfileSet -ne $null} | Where-Object {$PSItem.VirtualNetworkAdapterPortProfileSet.LogicalSwitch -eq $LogicalSwitch}
        If ($vnics.Count -gt 0)
        {
            $DependentVM++
        }
    }
    ForEach ($pcf In @(Get-SCPhysicalComputerProfile -All))
    {
        $pcf = Get-SCPhysicalComputerProfile -ID $pcf.ID
        $nicProfiles = $pcf.PhysicalComputerNetworkAdapterProfiles | Where-Object {$PSItem.LogicalSwitch -eq $LogicalSwitch}
        If ($nicProfiles.Count -gt 0)
        {
            $DependentPCF++
        }
    }
    If ($DependentHost -gt 0)
    {
        Write-Warning -Message "There are are Hosts dependent this Logical Switch."
        $AbleToRemove = $false
    }
    If ($DependentVM -gt 0)
    {
        Write-Warning -Message "There are are Virtual Machines dependent this Logical Switch."
        $AbleToRemove = $false
    }
    If ($DependentPCF -gt 0)
    {
        Write-Warning -Message "There are are Physical Computer Profiles dependent this Logical Switch."
        $AbleToRemove = $false
    }
    return $AbleToRemove
}

function Get-VirtualPortSets
{
    param($LogicalSwitch)
    
    [System.String[]]$returnValue = @()
    $NetworkPortSets = @(Get-SCVirtualNetworkAdapterPortProfileSet | Where-Object LogicalSwitch -eq $LogicalSwitch)
    ForEach ($NetworkPort In $NetworkPortSets)
    {
        $PortName = $NetworkPort.Name
        $PortClassification = $NetworkPort.PortClassification.Name
        $NetworkAdapterPortProfile = $null
        If ($NetworkPort.VirtualNetworkAdapterNativePortProfile)
        {
            $NetworkAdapterPortProfile = $NetworkPort.VirtualNetworkAdapterNativePortProfile.Name
        }
        [System.String]$AddPort = $PortName + ';' + $PortClassification
        If ($NetworkAdapterPortProfile)
        {
            $AddPort += ';' + $NetworkAdapterPortProfile
        }
        Write-Verbose -Message "Found Virtual Port: '$($AddPort)'."
        $returnValue += $AddPort
    }
    return $returnValue
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    
    Test-Requirements
    $script:ThisLogicalSwitch = Get-SCLogicalSwitch -Name $Name -VMMServer $env:COMPUTERNAME
    If ($ThisLogicalSwitch)
    {
        [System.String]$Ensure = "Present"
        [System.String]$Description = $ThisLogicalSwitch.Description
        [System.Boolean]$EnableSRIOV = $ThisLogicalSwitch.EnableSriov
        [System.String]$MinimumBandwidthMode = $ThisLogicalSwitch.MinimumBandwidthMode
        [System.String]$UplinkMode = $ThisLogicalSwitch.UplinkMode
        [System.String[]]$SwitchExtensions = @()
        ForEach ($Item In $ThisLogicalSwitch.VirtualSwitchExtensions)
        {
            $SwitchExtensions += $Item.Name
        }
        [System.String[]]$UplinkPortProfiles = @()
        ForEach ($Uplink In (Get-SCUplinkPortProfileSet | Where-Object LogicalSwitch -eq $ThisLogicalSwitch))
        {
            $UplinkPortProfiles += $Uplink.NativeUplinkPortProfile.Name
        }
        [System.String[]]$VirtualPorts = Get-VirtualPortSets -LogicalSwitch $ThisLogicalSwitch
    }
    Else
    {
        [System.String]$Ensure = "Absent"
        [System.String]$Description = ""
        [System.Boolean]$EnableSRIOV = ""
        [System.String]$UplinkMode = ""
        [System.String]$MinimumBandwidthMode = ""
        [System.String[]]$SwitchExtensions = @()
        [System.String[]]$VirtualPorts = @()
    }
    $returnValue = `
    @{
        Ensure = $Ensure
        Name = $Name
        Description = $Description
        EnableSRIOV = $EnableSRIOV
        MinimumBandwidthMode = $MinimumBandwidthMode
        SwitchExtensions = $SwitchExtensions
        UplinkMode = $UplinkMode
        UplinkPortProfiles = $UplinkPortProfiles
        VirtualPorts = $VirtualPorts
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
        
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,
        
        [System.String]
        $Description,
        
        [System.Boolean]
        $EnableSRIOV = $false,
        
        [System.String[]]
        $SwitchExtensions,
        
        [ValidateSet("Team","NoTeam")]
        [System.String]
        $UplinkMode = "Team",
        
        [System.String[]]
        $UplinkPortProfiles,
        
        [System.String[]]
        $VirtualPorts,
        
        [ValidateSet("Default","Absolute","Weight","None")]
        [System.String]
        $Bandwidth
    )
    
    Test-Requirements
    $script:ThisLogicalSwitch = Get-SCLogicalSwitch -Name $Name -VMMServer $env:COMPUTERNAME
    Switch ($Ensure)
    {
        "Present"
        {
            If (-not $Description)
            {
                $Description = "$Name - DSC created Logical Switch"
            }
            $ParamSet = `
            @{
                Name = $Name
                Description = $Description
                SwitchUplinkMode = $UplinkMode
                ErrorAction = 'Stop'
            }
            If (($EnableSRIOV) -and ($UplinkMode -eq "Team"))
            {
                throw New-TerminatingError -ErrorType TeamUplinkAndSRIOVNotAllowed
            }
            If ($ThisLogicalSwitch)
            {
                If ($ThisLogicalSwitch.EnableSriov -ne $EnableSRIOV)
                {
                    throw New-TerminatingError -ErrorType SRIOVCannotBeChanged
                }
                If ($Bandwidth)
                {
                    If ($ThisLogicalSwitch.MinimumBandwidthMode -ne $Bandwidth)
                    {
                        throw New-TerminatingError -ErrorType BandwidthCannotBeChanged
                    }
                }
                $ParamSet += @{LogicalSwitch = $ThisLogicalSwitch}
            }
            Else
            {
                $ParamSet += @{EnableSriov = $EnableSRIOV}
                If ($Bandwidth)
                {
                    $ParamSet += @{MinimumBandwidthMode = $Bandwidth}
                }
            }
            $VirtualSwitchExtensions = @()
            ForEach ($Extension In $SwitchExtensions)
            {
                If (($Extension -eq "Microsoft Windows Filtering Platform") -and ($EnableSRIOV))
                {
                    throw New-TerminatingError -ErrorType VirtualSwitchNotCompatibleWithSRIOV
                }
                $AddExtension = Get-SCVirtualSwitchExtension -Name $Extension
                If ($AddExtension)
                {
                    Write-Verbose -Message "Adding Switch Extension: '$($Extension)'."
                    $VirtualSwitchExtensions += $AddExtension
                }
                Else
                {
                    throw New-TerminatingError -ErrorType VirtualSwitchExtensionNotFound -FormatArgs @($Extension) -ErrorCategory ObjectNotFound
                }
            }
            $ParamSet += @{VirtualSwitchExtensions = $VirtualSwitchExtensions}
            $ParamSet.Keys | % { Write-Verbose -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
            Try
            {
                If ($ThisLogicalSwitch)
                {
                    Write-Verbose -Message "Changing Logical Switch named '$($Name)'."
                    $NewLogicalSwitch = Set-SCLogicalSwitch @ParamSet
                }
                Else
                {
                    Write-Verbose -Message "Creating Logical Switch named '$($Name)'."
                    $NewLogicalSwitch = New-SCLogicalSwitch @ParamSet
                }
            }
            Catch
            {
                Throw $PSItem.Exception
            }

            [System.String[]]$ExistingUplinkPortProfiles = @()
            ForEach ($Uplink In (Get-SCUplinkPortProfileSet -LogicalSwitch $NewLogicalSwitch))
            {
                $ExistingUplinkPortProfiles += $Uplink.NativeUplinkPortProfile.Name
            }
            ForEach ($UPP In $UplinkPortProfiles)
            {
                If ($ExistingUplinkPortProfiles -notcontains $UPP)
                {
                    $NativeProfile = Get-SCNativeUplinkPortProfile -Name $UPP
                    If ($NativeProfile)
                    {
                        [System.String]$SetName = $UPP + "_" + [guid]::NewGuid()
                        Write-Verbose -Message "Adding Uplink Port Profile named '$($SetName)'."
                        New-SCUplinkPortProfileSet -Name $SetName -LogicalSwitch $NewLogicalSwitch -NativeUplinkPortProfile $NativeProfile
                    }
                    Else
                    {
                        throw New-TerminatingError -ErrorType UplinkPortProfileNotFound -FormatArgs @($UPP) -ErrorCategory ObjectNotFound
                    }
                }
            }
            ForEach ($UPP In $ExistingUplinkPortProfiles)
            {
                If ($UplinkPortProfiles -notcontains $UPP)
                {
                    ForEach($ThisUPP In (Get-SCUplinkPortProfileSet -LogicalSwitch $NewLogicalSwitch | Where-Object DisplayName -eq $UPP))
                    {
                        Write-Verbose -Message "Removing Uplink Port Profile named '$($ThisUPP.Name)'."
                        $ThisUPP | Remove-SCUplinkPortProfileSet
                    }
                }
            }
            
            If ($VirtualPorts.Count -gt 0)
            {
                [System.String[]]$ExistingVirtualPorts = Get-VirtualPortSets -LogicalSwitch $NewLogicalSwitch

                ForEach ($Port In $ExistingVirtualPorts)
                {
                    If ($VirtualPorts -notcontains $Port)
                    {
                        Write-Verbose -Message "Need to remove Virtual Port: '$($Port)'."
                        [System.String]$PortName = $Port.Split(';')[0]
                        [System.String]$PortClassification = $Port.Split(';')[1]
                        [System.String]$NetworkAdapterPortProfile = $null
                        If ($Port.Split(';').Count -ge 3)
                        {
                            $NetworkAdapterPortProfile = $Port.Split(';')[2]
                        }
                        $PortProfileSetToRemove = Get-SCVirtualNetworkAdapterPortProfileSet -Name $PortName -LogicalSwitch $NewLogicalSwitch
                        If (-not $PortProfileSetToRemove)
                        {
                            throw New-TerminatingError -ErrorType PortProfileSetNotFound -FormatArgs @($PortName, $NewLogicalSwitch) -ErrorCategory ObjectNotFound
                        }
                        Try
                        {
                            Write-Verbose -Message "Removing Virtual Port named: '$($PortName)'."
                            Remove-SCVirtualNetworkAdapterPortProfileSet -VirtualNetworkAdapterPortProfileSet $PortProfileSetToRemove -ErrorAction Stop
                        }
                        Catch
                        {
                            Throw $PSItem.Exception
                        }
                    }
                }
                ForEach ($Port In $VirtualPorts)
                {
                    If ($ExistingVirtualPorts -notcontains $Port)
                    {
                        Write-Verbose -Message "Need to add Virtual Port: '$($Port)'."
                        If ($Port.Split(';').Count -lt 2)
                        {
                            throw New-TerminatingError -ErrorType InvalidPortFormat -TargetObject $Port
                        }
                        [System.String]$PortName = $Port.Split(';')[0]
                        [System.String]$PortClassification = $Port.Split(';')[1]
                        [System.String]$NetworkAdapterPortProfile = $null
                        If ($Port.Split(';').Count -ge 3)
                        {
                            $NetworkAdapterPortProfile = $Port.Split(';')[2]
                        }
                        $ThisPortClassification = Get-SCPortClassification -Name $PortClassification
                        If (-not $ThisPortClassification)
                        {
                            throw New-TerminatingError -ErrorType PortClassificationNotFound -FormatArgs @($ThisPortClassification) -ErrorCategory ObjectNotFound 
                        }
                        $ParamSet = `
                        @{
                            Name = $PortName
                            PortClassification = $ThisPortClassification
                            LogicalSwitch = $NewLogicalSwitch
                            ErrorAction = 'Stop'
                        }
                        If ($NetworkAdapterPortProfile)
                        {
                            $NativeProfile = Get-SCVirtualNetworkAdapterNativePortProfile -Name $NetworkAdapterPortProfile
                            If ($NativeProfile)
                            {
                                $ParamSet += @{VirtualNetworkAdapterNativePortProfile = $NativeProfile}
                            }
                            Else
                            {
                                throw New-TerminatingError -ErrorType NetworkAdapterPortNotFound -FormatArgs @($NetworkAdapterPortProfile) -ErrorCategory ObjectNotFound 
                            }
                        }
                        $ParamSet.Keys | % { Write-Verbose -Message ( "PARAMETER: " + $PSItem + " = " + $ParamSet.$PSItem ) }
                        Try
                        {
                            Write-Verbose -Message "Adding Virtual Port named: '$($PortName)'."
                            New-SCVirtualNetworkAdapterPortProfileSet @ParamSet
                        }
                        Catch
                        {
                            Throw $PSItem.Exception
                        }
                    }
                }
            }
        }
        "Absent"
        {
            If (Check-AbleToRemove -LogicalSwitch $ThisLogicalSwitch)
            {
                Write-Verbose -Message "Removing Logical Switch named '$($Name)'."
                Try
                {
                    $ThisLogicalSwitch | Remove-SCLogicalSwitch
                }
                Catch
                {
                    Throw $PSItem.Exception
                }
            }
            Else
            {
                throw New-TerminatingError -ErrorType LogicalSwitchInUse -TargetObject $ThisLogicalSwitch -ErrorCategory InvalidOperation
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
        
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,
        
        [System.String]
        $Description,
        
        [System.Boolean]
        $EnableSRIOV = $false,
        
        [System.String[]]
        $SwitchExtensions,
        
        [ValidateSet("Team","NoTeam")]
        [System.String]
        $UplinkMode = "Team",
        
        [System.String[]]
        $UplinkPortProfiles,
        
        [System.String[]]
        $VirtualPorts,
        
        [ValidateSet("Default","Absolute","Weight","None")]
        [System.String]
        $Bandwidth
    )
    
    Test-Requirements
    [System.Boolean]$result = $true
    $CurrentConfig = Get-TargetResource -Name $Name
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: Virtual Switch named '$($Name)' is '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        Write-Verbose -Message "Validate Virtual Switch named '$($Name)'."
        If ($Description)
        {
            If ($CurrentConfig.Description -ne $Description)
            {
                Write-Verbose -Message "FAIL: Description is incorrect."
                $result = $false
            }
        }
        
        If ($CurrentConfig.EnableSRIOV -ne $EnableSRIOV)
        {
            Write-Verbose -Message "FAIL: EnableSRIOV setting is incorrect."
            $result = $false
        }

        If ($Bandwidth)
        {
            If ($CurrentConfig.MinimumBandwidthMode -ne $Bandwidth)
            {
                Write-Verbose -Message "FAIL: MinimumBandwidthMode setting is incorrect."
                $result = $false
            }
        }

        ForEach ($Extension In $SwitchExtensions)
        {
            If ($CurrentConfig.SwitchExtensions -notcontains $Extension)
            {
                Write-Verbose -Message "FAIL: Switch Extension '$($Extension)' is not present on this Logical Switch."
                $result = $false
            }
        }

        ForEach ($Extension In $CurrentConfig.SwitchExtensions)
        {
            If ($SwitchExtensions -notcontains $Extension)
            {
                Write-Verbose -Message "FAIL: Switch Extension '$($Extension)' should not be present on this Logical Switch."
                $result = $false
            }
        }
        
        If ($CurrentConfig.UplinkMode -ne $UplinkMode)
        {
            Write-Verbose -Message "FAIL: UplinkMode setting is incorrect."
            $result = $false
        }
        
        ForEach ($Profile In $UplinkPortProfiles)
        {
            If ($CurrentConfig.UplinkPortProfiles -notcontains $Profile)
            {
                Write-Verbose -Message "FAIL: Uplink Port Profile '$($Profile)' is not present on this Logical Switch."
                $result = $false
            }
        }

        ForEach ($Profile In $CurrentConfig.UplinkPortProfiles)
        {
            If ($UplinkPortProfiles -notcontains $Profile)
            {
                Write-Verbose -Message "FAIL: Uplink Port Profile '$($Profile)' should not be present on this Logical Switch."
                $result = $false
            }
        }
        
        ForEach ($PortSet In $VirtualPorts)
        {
            If ($CurrentConfig.VirtualPorts -notcontains $PortSet)
            {
                Write-Verbose -Message "FAIL: Virtual Port '$($PortSet)' is not present on this Logical Switch."
                $result = $false
            }
        }

        ForEach ($PortSet In $CurrentConfig.VirtualPorts)
        {
            If ($VirtualPorts -notcontains $PortSet)
            {
                Write-Verbose -Message "FAIL: Virtual Port '$($PortSet)' should not be present on this Logical Switch."
                $result = $false
            }
        }
    }
    return $result
}

Export-ModuleMember -Function *-TargetResource
