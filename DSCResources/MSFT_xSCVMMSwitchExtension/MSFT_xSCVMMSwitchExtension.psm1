$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Test-Requirements
{
    param
    (
        [System.String]
        $Ensure,
        
        [System.String]
        $VirtualSwitch,
        
        [System.String]
        $VMMLogicalSwitch,
        
        [System.String]
        $VMMUplinkPortProfile,
        
        [System.String]
        $VMMServer
    )
    
    Try
    {
        If (-not (Get-Module Hyper-V -ErrorAction SilentlyContinue))
        {
            Write-Verbose -Message "Importing the Hyper-V PowerShell module"
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = "SilentlyContinue"
            $null = Import-Module Hyper-V -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
        }
        If (-not [string]::IsNullOrWhiteSpace($VMMLogicalSwitch))
        {
            Write-Verbose -Message "Attempting to establish a connection to VMM server named '$($VMMServer)'."
            $retryCount = 1
            $maxRetry = 10
            $sleepSeconds = 30
            $vmmConnection = $false
            Do
            {
                $script:vmmSession = New-PSSession -ComputerName $VMMServer -ErrorAction SilentlyContinue
                If ($vmmSession)
                {
                    If (Invoke-Command -Session $vmmSession -ScriptBlock { $true } -ErrorAction SilentlyContinue)
                    {
                        $vmmConnection = $true
                        $retryCount = $maxRetry + 1
                    }
                }
                If (-not $vmmConnection)
                {
                    Write-Verbose -Message ("Connection attempt {0} of {1} failed." -f $retryCount,$maxRetry )
                    Start-Sleep -Seconds $sleepSeconds
                    $retryCount++
                }
            } While ($retryCount -le $maxRetry)
            If(-not $vmmConnection)
            {
                throw New-TerminatingError -ErrorType RemoteConnectionFailed -FormatArgs @($VMMServer)
            }
            Invoke-Command -Session $vmmSession -ScriptBlock `
            {
                If (-not (Get-Module VirtualMachineManager -ErrorAction SilentlyContinue))
                {
                    Write-Verbose -Message "Importing the VirtualMachineManager PowerShell module"
                    $CurrentVerbose = $VerbosePreference
                    $VerbosePreference = "SilentlyContinue"
                    $null = Import-Module VirtualMachineManager -ErrorAction Stop
                    $VerbosePreference = $CurrentVerbose
                }
            }
            $script:vmmMap = Get-VMMSwitchMap -VMMLogicalSwitch $VMMLogicalSwitch -VMMUplinkPortProfile $VMMUplinkPortProfile
            If (-not $vmmMap)
            {
                throw New-TerminatingError -ErrorType FailedToGetSwitch -FormatArgs @($VMMServer)
            }
            Remove-PSSession -Session $vmmSession
        }
        Else
        {
            throw New-TerminatingError -ErrorType VMMLogicalSwitchRequired
        }
    }
    Catch
    {
        Throw $PSItem.Exception
    }
    $script:VMMFeatureId = "8b54c928-eb03-4aff-8039-99171dd900ff"
    $script:VMMPortFeatureId = "1f59a509-a6ba-4aba-8504-b29d542d44bb"
}

function Get-VMMSwitchMap
{
    param
    (
        $VMMLogicalSwitch,
        $VMMUplinkPortProfile
    )
    $returnValue = Invoke-Command -Session $vmmSession -ScriptBlock `
    {
        $map = @{}
        $switch = Get-SCLogicalSwitch -Name $using:VMMLogicalSwitch -VMMServer $env:COMPUTERNAME
        If ($switch)
        {
            $map["LogicalSwitchID"] = $switch.ID
        }
        $set = (Get-SCUplinkPortProfileSet -LogicalSwitch $switch -VMMServer $env:COMPUTERNAME | Where-Object DisplayName -eq $using:VMMUplinkPortProfile)
        If ($set)
        {
            $map["UplinkPortProfileSetID"] = $set.ID
            $map["UplinkPortProfileSetName"] = $set.Name
        }
        $map
    }
    If (-not $returnValue.LogicalSwitchID)
    {
        throw New-TerminatingError -ErrorType LocalSwitchNotFound -FormatArgs @($VMMLogicalSwitch)
    }
    If (-not (($returnValue.UplinkPortProfileSetID) -and ($returnValue.UplinkPortProfileSetName)))
    {
        throw New-TerminatingError -ErrorType UplinkPortNotFound -FormatArgs @($VMMUplinkPortProfile)
    }
    return $returnValue
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,
        
        [parameter(Mandatory = $true)]
        [System.String]
        $VirtualSwitch,
        
        [System.String]
        $VMMLogicalSwitch,
        
        [System.String]
        $VMMUplinkPortProfile,
        
        [System.String]
        $VMMServer
    )
    
    Try
    {
        Test-Requirements @PSBoundParameters
        [System.String]$Ensure = "Absent"
        [System.String]$ThisLogicalSwitchName = ""
        [System.String]$ThisLogicalSwitchId  = ""
        [System.String]$ThisVMMUplinkPortProfileId  = ""
        [System.String]$ThisVMMUplinkPortProfileName = ""
        
        $vSwitch = Get-VMSwitch -Name $VirtualSwitch
        If (-not $vSwitch)
        {
            throw New-TerminatingError -ErrorType VirtualSwitchNotFound -FormatArgs @($VirtualSwitch, $env:COMPUTERNAME)
        }
        $currentFeature = Get-VMSwitchExtensionSwitchFeature -SwitchName $VirtualSwitch -FeatureId $VMMFeatureId -ErrorAction Stop
        If ($currentFeature)
        {
            $Ensure = "Present"
            $ThisLogicalSwitchId = $currentFeature.SettingData.LogicalSwitchId
            $ThisLogicalSwitchName = $currentFeature.SettingData.LogicalSwitchName
            
            $existingFeatures = Get-VMSwitchExtensionPortFeature -SwitchName $VirtualSwitch -ExternalPort -FeatureId $VMMPortFeatureId -ErrorAction Stop
            If ($existingFeatures)
            {
                $ThisVMMUplinkPortProfileId = $existingFeatures.SettingData.PortProfileSetId
                $ThisVMMUplinkPortProfileName = $existingFeatures.SettingData.PortProfileSetName
            }
        }
    }
    Catch
    {
        Throw $PSItem.Exception
    }
    
    $returnValue = `
    @{
        Ensure                   = $Ensure
        VMMLogicalSwitch         = $ThisLogicalSwitchName
        VMMLogicalSwitchId       = $ThisLogicalSwitchId
        VMMUplinkPortProfileName = $ThisVMMUplinkPortProfileName
        VMMUplinkPortProfileId   = $ThisVMMUplinkPortProfileId
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
        $VirtualSwitch,
        
        [System.String]
        $VMMLogicalSwitch,
        
        [System.String]
        $VMMUplinkPortProfile,
        
        [System.String]
        $VMMServer
    )

    If (($Ensure = "Present") -and (-not ($VMMLogicalSwitch -and $VMMUplinkPortProfile -and $VMMServer)))
    {
        throw New-TerminatingError -ErrorType AllSwitchParametersRequired
    }
    
    Try
    {
        Test-Requirements @PSBoundParameters
        $vSwitch = Get-VMSwitch -Name $VirtualSwitch -ErrorAction Stop
        $currentFeature = Get-VMSwitchExtensionSwitchFeature -SwitchName $VirtualSwitch -FeatureId $VMMFeatureId
        If ($currentFeature -ne $null)
        {
            Write-Debug -Message "Removing existing VMM Switch Feature."
            Remove-VMSwitchExtensionSwitchFeature -SwitchName $VirtualSwitch -VMSwitchExtensionFeature $currentFeature -ErrorAction Stop
        }
        $defaultFeature = Get-VMSystemSwitchExtensionSwitchFeature -FeatureId $VMMFeatureId -ErrorAction Stop
        $wmiObj = [wmi]$defaultFeature.SettingData
        $wmiObj.LogicalSwitchId = $vmmMap.LogicalSwitchID
        $wmiObj.LogicalSwitchName = $VirtualSwitch
        Write-Verbose -Message "Adding VMM Switch Feature for Logical Switch ID '$($vmmMap.LogicalSwitchID)' to Hyper-V Switch '$($VirtualSwitch)'."
        Add-VMSwitchExtensionSwitchFeature -SwitchName $VirtualSwitch -VMSwitchExtensionFeature $defaultFeature -ErrorAction Stop
        
        $cimSession = New-CimSession -ComputerName localhost
        $netAdapter = Get-NetAdapter -InterfaceDescription $vSwitch.NetAdapterInterfaceDescription -CimSession $cimSession -ErrorAction Stop
        $existingFeatures = Get-VMSwitchExtensionPortFeature -SwitchName $VirtualSwitch -ExternalPort -FeatureId $VMMPortFeatureId -ErrorAction Stop
        If ($existingFeatures -ne $null)
        {
            Write-Debug -Message "Removing existing VMM Port Feature."
            Remove-VMSwitchExtensionPortFeature -SwitchName $VirtualSwitch -ExternalPort -VMSwitchExtensionFeature $existingFeatures -ErrorAction Stop
        }
        $defaultPortFeature = Get-VMSystemSwitchExtensionPortFeature -FeatureId $VMMPortFeatureId -ErrorAction Stop
        $wmiPortObj = [wmi]$defaultPortFeature.SettingData
        $wmiPortObj.PortProfileSetId = $vmmMap.UplinkPortProfileSetID
        $wmiPortObj.PortProfileSetName = $vmmMap.UplinkPortProfileSetName
        $wmiPortObj.NetCfgInstanceId = $netAdapter.InterfaceGuid
        Write-Verbose -Message "Adding VMM Uplink Port '$($vmmMap.UplinkPortProfileSetName)' to Hyper-V Switch '$($VirtualSwitch)'."
        Add-VMSwitchExtensionPortFeature -SwitchName $VirtualSwitch -VMSwitchExtensionFeature $defaultPortFeature –ExternalPort -ErrorAction Stop
    }
    Catch
    {
        Throw $PSItem.Exception
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
        $VirtualSwitch,
        
        [System.String]
        $VMMLogicalSwitch,
        
        [System.String]
        $VMMUplinkPortProfile,
        
        [System.String]
        $VMMServer
    )
    
    [System.Boolean]$result = $true
    
    Try
    {
        Test-Requirements @PSBoundParameters
    }
    Catch
    {
        Throw $PSItem.Exception
    }
    
    $CurrentConfig = Get-TargetResource @PSBoundParameters
    If ($CurrentConfig.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "FAIL: VMM Switch Settings are '$($CurrentConfig.Ensure)' when it should be '$($Ensure)'."
        $result = $false
    }
    ElseIf ($Ensure -eq "Present")
    {
        If ($CurrentConfig.VMMLogicalSwitch -ne $VirtualSwitch)
        {
            Write-Verbose -Message "FAIL: VMM Logical Switch named '$($CurrentConfig.VMMLogicalSwitch)' was found when '$($VirtualSwitch)' was expected."
            $result = $false
        }
        If ($CurrentConfig.VMMLogicalSwitchId -ne $vmmMap.LogicalSwitchID)
        {
            Write-Verbose -Message "FAIL: The VMM Logical Switch ID '$($CurrentConfig.VMMLogicalSwitchId)' does not match the expected ID '$($vmmMap.LogicalSwitchID)'."
            $result = $false
        }
        If ($CurrentConfig.VMMUplinkPortProfileName -ne $vmmMap.UplinkPortProfileSetName)
        {
            Write-Verbose -Message "FAIL: The VMM Uplink Port name '$($CurrentConfig.VMMUplinkPortProfileName)' does not match the expected name '$($vmmMap.UplinkPortProfileSetName)'."
            $result = $false
        }
        If ($CurrentConfig.VMMUplinkPortProfileId -ne $vmmMap.UplinkPortProfileSetID)
        {
            Write-Verbose -Message "FAIL: The VMM Uplink Port ID '$($CurrentConfig.VMMUplinkPortProfileId)' does not match the expected ID '$($vmmMap.UplinkPortProfileSetID)'."
            $result = $false
        }
    }
    return $result
}

Export-ModuleMember -Function *-TargetResource
