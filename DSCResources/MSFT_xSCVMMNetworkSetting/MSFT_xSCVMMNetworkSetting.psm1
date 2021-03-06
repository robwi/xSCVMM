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
        [System.Boolean]
        $AutomaticLogicalNetworkCreation
    )
    
    Test-Requirements
    $VMMSettings = Get-SCVMMServer -ComputerName $Env:COMPUTERNAME
    If (-not $VMMSettings)
    {
        throw New-TerminatingError -ErrorType FailedToConnectToVMMServer -FormatArgs @($env:COMPUTERNAME)
    }
    
    [System.Boolean]$AutomaticLogicalNetworkCreation = $VMMSettings.AutomaticLogicalNetworkCreationEnabled
    [System.String]$LogicalNetworkMatch = $VMMSettings.LogicalNetworkMatchOption
    [System.String]$BackupLogicalNetworkMatch = $VMMSettings.BackupLogicalNetworkMatchOption
    
    $returnValue = `
    @{
        AutomaticLogicalNetworkCreation = $AutomaticLogicalNetworkCreation
        AutomaticVirtualNetworkCreation = $AutomaticVirtualNetworkCreation
        LogicalNetworkMatch = $LogicalNetworkMatch
        BackupLogicalNetworkMatch = $BackupLogicalNetworkMatch
    }
    return $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.Boolean]
        $AutomaticLogicalNetworkCreation,
        
        [ValidateSet("FirstDNSSuffixLabel","DNSSuffix","NetworkConnectionName","VirtualNetworkSwitchName","Disabled")]
        [System.String]
        $LogicalNetworkMatch = "FirstDNSSuffixLabel",
        
        [ValidateSet("FirstDNSSuffixLabel","DNSSuffix","NetworkConnectionName","VirtualNetworkSwitchName","Disabled")]
        [System.String]
        $BackupLogicalNetworkMatch = "VirtualNetworkSwitchName"
    )
    
    Test-Requirements
    If ($LogicalNetworkMatch -ne "Disabled")
    {
        If ($LogicalNetworkMatch -eq $BackupLogicalNetworkMatch)
        {
            throw New-TerminatingError -ErrorType BackupNetworkMustMatchLogical
        }
    }
    If (($LogicalNetworkMatch -eq "Disabled") -and ($BackupLogicalNetworkMatch -ne "Disabled"))
    {
        Write-Warning "LogicalNetworkMatch is set to 'Disabled', the BackupLogicalNetworkMatch setting will also be 'Disabled'."
        $BackupLogicalNetworkMatch = "Disabled"
    }
    If (($LogicalNetworkMatch -eq "Disabled") -and ($AutomaticLogicalNetworkCreation -eq $true))
    {
        throw New-TerminatingError -ErrorType LogicalNetworkMatchNotDisabled
    }
    
    Try
    {
        Write-Verbose -Message "Changing VMM Network settings."
        Set-SCVMMServer -VMMServer $env:COMPUTERNAME -AutomaticLogicalNetworkCreationEnabled $AutomaticLogicalNetworkCreation -LogicalNetworkMatch $LogicalNetworkMatch -BackupLogicalNetworkMatch $BackupLogicalNetworkMatch
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
        [parameter(Mandatory = $true)]
        [System.Boolean]
        $AutomaticLogicalNetworkCreation,
        
        [ValidateSet("FirstDNSSuffixLabel","DNSSuffix","NetworkConnectionName","VirtualNetworkSwitchName","Disabled")]
        [System.String]
        $LogicalNetworkMatch = "FirstDNSSuffixLabel",
        
        [ValidateSet("FirstDNSSuffixLabel","DNSSuffix","NetworkConnectionName","VirtualNetworkSwitchName","Disabled")]
        [System.String]
        $BackupLogicalNetworkMatch = "VirtualNetworkSwitchName"
    )
    
    Test-Requirements
    [System.Boolean]$result = $true
    $CurrentConfig = Get-TargetResource -AutomaticLogicalNetworkCreation $AutomaticLogicalNetworkCreation
    
    If (($LogicalNetworkMatch -eq "Disabled") -and ($BackupLogicalNetworkMatch -ne "Disabled"))
    {
        $BackupLogicalNetworkMatch = "Disabled"
    }
    If ($CurrentConfig.AutomaticLogicalNetworkCreation -ne $AutomaticLogicalNetworkCreation)
    {
        Write-Verbose -Message "FAIL: AutomaticLogicalNetworkCreation setting is incorrect."
        $result = $false
    }
    If ($CurrentConfig.LogicalNetworkMatch -ne $LogicalNetworkMatch)
    {
        Write-Verbose -Message "FAIL: LogicalNetworkMatch setting is incorrect."
        $result = $false
    }
    If ($CurrentConfig.BackupLogicalNetworkMatch -ne $BackupLogicalNetworkMatch)
    {
        Write-Verbose -Message "FAIL: BackupLogicalNetworkMatch setting is incorrect."
        $result = $false
    }
    return $result
}

Export-ModuleMember -Function *-TargetResource
