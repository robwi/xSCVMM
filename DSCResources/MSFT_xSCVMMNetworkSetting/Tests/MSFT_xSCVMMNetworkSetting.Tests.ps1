<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMNetworkSetting.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMNetworkSetting.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}

Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    function Set-SCVMMServer
    {
        param
        (
           [System.String]$VMMServer
        )
    }
    function Get-SCVMMServer
    {
        param
        (
            [Parameter(Mandatory = $true)]
            [System.String]$ComputerName
        )
        return $true
    }
    Export-ModuleMember -Function *
} | Import-Module -Force

Describe "MSFT_xSCVMMNetworkSetting Tests" {

    $global:FunctionCounter = 0
    
    AfterEach {
        $global:FunctionCounter = 0
    }
    
    Context "Get Succeeds" {
        Mock -ModuleName MSFT_xSCVMMNetworkSetting Get-SCVMMServer -Verifiable {
            $Item = New-Object PSObject -Property @{
                AutomaticLogicalNetworkCreationEnabled = $true
                AutomaticVirtualNetworkCreationEnabled = $false
                LogicalNetworkMatchOption = "FirstDNSSuffixLabel"
                BackupLogicalNetworkMatchOption = "VirtualNetworkSwitchName"
            }
            return $Item
        }
        It "Get-TargetResource succeeds" {
            $result = Get-TargetResource -AutomaticLogicalNetworkCreation $true -Verbose -Debug:$false
            $result.AutomaticLogicalNetworkCreation | Should Be $true
            $result.AutomaticVirtualNetworkCreation | Should Be $false
            $result.LogicalNetworkMatch | Should Be "FirstDNSSuffixLabel"
            $result.BackupLogicalNetworkMatch | Should Be "VirtualNetworkSwitchName"
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMNetworkSetting Get-SCVMMServer -Verifiable {
        }
        It "Get-TargetResource fails when VMM Settings cannot be retrieved" {
            {Get-TargetResource -AutomaticLogicalNetworkCreation $true -Verbose -Debug:$false} | Should Throw "Unable to retrieve VMM Settings from '$($env:COMPUTERNAME)'."
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMNetworkSetting Get-SCVMMServer -Verifiable {
            If ($global:FunctionCounter -le 2)
            {
                $Item = New-Object PSObject -Property @{
                    AutomaticLogicalNetworkCreationEnabled = $true
                    AutomaticVirtualNetworkCreationEnabled = $false
                    LogicalNetworkMatchOption = "VirtualNetworkSwitchName"
                    BackupLogicalNetworkMatchOption = "FirstDNSSuffixLabel"
                }
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    AutomaticLogicalNetworkCreationEnabled = $false
                    AutomaticVirtualNetworkCreationEnabled = $false
                    LogicalNetworkMatchOption = "FirstDNSSuffixLabel"
                    BackupLogicalNetworkMatchOption = "VirtualNetworkSwitchName"
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        It "Set-TargetResource succeeds when changes are made to network settings" {
            $result = Test-TargetResource -AutomaticLogicalNetworkCreation $false -LogicalNetworkMatch "FirstDNSSuffixLabel" -BackupLogicalNetworkMatch "VirtualNetworkSwitchName" -Verbose -Debug:$false
            $result | Should Be $false
            $result = Set-TargetResource -AutomaticLogicalNetworkCreation $false -LogicalNetworkMatch "FirstDNSSuffixLabel" -BackupLogicalNetworkMatch "VirtualNetworkSwitchName" -Verbose -Debug:$false
            $result = Test-TargetResource -AutomaticLogicalNetworkCreation $false -LogicalNetworkMatch "FirstDNSSuffixLabel" -BackupLogicalNetworkMatch "VirtualNetworkSwitchName" -Verbose -Debug:$false
            $result | Should Be $true
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Fails" {
        Mock -ModuleName MSFT_xSCVMMNetworkSetting Get-SCVMMServer -Verifiable {
        }
        It "Set-TargetResource fails when LogicalNetworkMatch and BackupLogicalNetworkMatch are the same" {
            {Set-TargetResource -AutomaticLogicalNetworkCreation $false -LogicalNetworkMatch "FirstDNSSuffixLabel" -BackupLogicalNetworkMatch "FirstDNSSuffixLabel" -Verbose -Debug:$false} | Should Throw "BackupLogicalNetworkMatch must not be the same as LogicalNetworkMatch."
        }
    }
    
}

Get-Module -Name VirtualMachineManager | Remove-Module
