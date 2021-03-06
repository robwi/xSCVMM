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
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    
    Test-Requirements
    $ThisUplinkPortProfile = Get-SCNativeUplinkPortProfile -VMMServer $env:COMPUTERNAME -Name $Name
    If ($ThisUplinkPortProfile)
    {
        $Ensure = "Present"
        $Description = $ThisUplinkPortProfile.Description
        $LoadBalancingAlgorithm = $ThisUplinkPortProfile.LBFOLoadBalancingAlgorithm
        $TeamMode = $ThisUplinkPortProfile.LBFOTeamMode
        $NetworkVirtualization = $ThisUplinkPortProfile.EnableNetworkVirtualization
        $NetworkSite = @()
        ForEach ($Item In $ThisUplinkPortProfile.LogicalNetworkDefinitions)
        {
            $AddSite = $Item.Name + ';' + $Item.LogicalNetwork
            Write-Debug -Message "Found Network Site: '$($AddSite)'."
            $NetworkSite += $AddSite
        }
    }
    Else
    {
        $Ensure = "Absent"
        $Description = ""
        $LoadBalancingAlgorithm = ""
        $TeamMode = ""
        $NetworkSite = @()
        $NetworkVirtualization = $false
    }
    
    $returnValue = `
    @{
        Ensure = $Ensure
        Name = $Name
        Description = $Description
        LoadBalancingAlgorithm = $LoadBalancingAlgorithm
        TeamMode = $TeamMode
        NetworkSite = $NetworkSite
        NetworkVirtualization = $NetworkVirtualization
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
        
        [ValidateSet("HostDefault","IPAddresses","MacAddresses","HyperVPort","Dynamic","TransportPorts")]
        [System.String]
        $LoadBalancingAlgorithm = "Dynamic",
        
        [ValidateSet("Static","SwitchIndependent","LACP")]
        [System.String]
        $TeamMode = "LACP",
        
        [System.String[]]
        $NetworkSite,
        
        [System.Boolean]
        $NetworkVirtualization = $false
    )
    
    Test-Requirements
    $ThisUplinkPortProfile = Get-SCNativeUplinkPortProfile -VMMServer $env:COMPUTERNAME -Name $Name
    Switch ($Ensure)
    {
        "Present"
        {
            If (-not $Description)
            {
                $Description = "$Name - DSC created Uplink Port Profile"
            }
            $ParamSet = `
            @{
                Name = $Name
                Description = $Description
                EnableNetworkVirtualization = $NetworkVirtualization
                LBFOLoadBalancingAlgorithm = $LoadBalancingAlgorithm
                LBFOTeamMode = $TeamMode
            }
            $ExistingDefinition = @()
            $DefinitionsToRemove = @()
            If ($ThisUplinkPortProfile)
            {
                ForEach ($Site In $ThisUplinkPortProfile.LogicalNetworkDefinitions)
                {
                    $ThisSite = $Site.Name + ';' + $Site.LogicalNetwork
                    $ExistingDefinition += $ThisSite
                    If ($NetworkSite -notcontains $ThisSite)
                    {
                        Write-Debug -Message "Remove Network Site: '$($Site.Name)' on Logical Network: '$($Site.LogicalNetwork)' from this port profile."
                        $DefinitionsToRemove += Get-SCLogicalNetworkDefinition $Site
                    }
                }
            }
            $DefinitionsToAdd = @()
            If ($NetworkSite.Count -gt 0)
            {
                ForEach ($Site In $NetworkSite)
                {
                    If ($ExistingDefinition -notcontains $Site)
                    {
                        If ($Site.Split(';').Count -ne 2)
                        {
                            throw New-TerminatingError -ErrorType NetworkSiteInvalidFormat -FormatArgs @($Site)
                        }
                        $SiteName = $Site.Split(';')[0]
                        $LogicalNetwork = $Site.Split(';')[1]
                        Write-Debug -Message "Add Network Site: '$($SiteName)' on Logical Network: '$($LogicalNetwork)' to this port profile."
                        $AddDefinition = Get-SCLogicalNetworkDefinition -Name $SiteName -LogicalNetwork $LogicalNetwork
                        If (-not $AddDefinition)
                        {
                            throw New-TerminatingError -ErrorType NetworkSiteNotFound -FormatArgs @($SiteName,$LogicalNetwork)
                        }
                        $DefinitionsToAdd+= $AddDefinition
                    }
                }
            }
            If ($ThisUplinkPortProfile)
            {
                $ParamSet += @{NativeUplinkPortProfile = $ThisUplinkPortProfile}
                If ($DefinitionsToAdd.Count -gt 0)
                {
                    $ParamSet += @{AddLogicalNetworkDefinition = $DefinitionsToAdd}
                }
                If ($DefinitionsToRemove.Count -gt 0)
                {
                    $ParamSet += @{RemoveLogicalNetworkDefinition = $DefinitionsToRemove}
                }
                Write-Verbose -Message "Changing Uplink Port Profile named '$($Name)'."
                Set-SCNativeUplinkPortProfile @ParamSet
            }
            Else
            {
                If ($DefinitionsToAdd.Count -gt 0)
                {
                    $ParamSet += @{LogicalNetworkDefinition = $DefinitionsToAdd}
                }
                Write-Verbose -Message "Creating Uplink Port Profile named '$($Name)'."
                New-SCNativeUplinkPortProfile @ParamSet
            }
        }
        "Absent"
        {
            $UplinkPortProfileSets = Get-SCUplinkPortProfileSet | Where-Object NativeUplinkPortProfile -eq $ThisUplinkPortProfile
            If ($UplinkPortProfileSets)
            {
                Write-Verbose -Message "Removing Uplink Port Profile Sets from Logical Switches."
                ForEach ($UplinkPortProfileToRemove In $UplinkPortProfileSets)
                {
                    Remove-SCUplinkPortProfileSet -UplinkPortProfileSet $UplinkPortProfileToRemove
                }
            }
            Write-Verbose -Message "Removing Uplink Port Profile."
            $ThisUplinkPortProfile | Remove-SCNativeUplinkPortProfile
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
        
        [ValidateSet("HostDefault","IPAddresses","MacAddresses","HyperVPort","Dynamic","TransportPorts")]
        [System.String]
        $LoadBalancingAlgorithm = "Dynamic",
        
        [ValidateSet("Static","SwitchIndependent","LACP")]
        [System.String]
        $TeamMode = "LACP",
        
        [System.String[]]
        $NetworkSite,
        
        [System.Boolean]
        $NetworkVirtualization = $false
    )
    
    Test-Requirements
    [System.Boolean]$result = $true
    $CurrentConfig = Get-TargetResource -Name $Name
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: Uplink Port Profile named '$($Name)' is '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        Write-Verbose -Message "Validate Uplink Port Profile named '$($Name)'."
        If ($Description)
        {
            If ($CurrentConfig.Description -ne $Description)
            {
                Write-Verbose -Message "FAIL: Description is incorrect."
                $result = $false
            }
        }
        If ($CurrentConfig.LoadBalancingAlgorithm -ne $LoadBalancingAlgorithm)
        {
            Write-Verbose -Message "FAIL: Load Balancing Algorithm is '$($CurrentConfig.LoadBalancingAlgorithm)' when it should be '$($LoadBalancingAlgorithm)'."
            $result = $false
        }
        If ($CurrentConfig.TeamMode -ne $TeamMode)
        {
            Write-Verbose -Message "FAIL: Team Mode is '$($CurrentConfig.TeamMode)' when it should be '$($TeamMode)'."
            $result = $false
        }
        If ($CurrentConfig.NetworkVirtualization -ne $NetworkVirtualization)
        {
            Write-Verbose -Message "FAIL: Network Virtualization '$($CurrentConfig.NetworkVirtualization)' when it should be '$($NetworkVirtualization)'."
            $result = $false
        }
        ForEach ($Site In $NetworkSite)
        {
            If ($CurrentConfig.NetworkSite -notcontains $Site)
            {
                Write-Verbose -Message "FAIL: Network Site '$($Site)' is not present."
                $result = $false
            }
        }
        ForEach ($Site In $CurrentConfig.NetworkSite)
        {
            If ($NetworkSite -notcontains $Site)
            {
                Write-Verbose -Message "FAIL: Network Site '$($Site)' should not be present."
                $result = $false
            }
        }
    }
    
    return $result
}

Export-ModuleMember -Function *-TargetResource
