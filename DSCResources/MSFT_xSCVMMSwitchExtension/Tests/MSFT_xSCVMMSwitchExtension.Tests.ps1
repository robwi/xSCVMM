<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMSwitchExtension.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMSwitchExtension.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}

Get-Module -Name Hyper-V | Remove-Module
New-Module -Name Hyper-V -ScriptBlock `
{
    function Get-VMSwitch
    {
        param
        (
            $Name
        )
    }
    function Get-VMSwitchExtensionSwitchFeature
    {
    }
    function Get-VMSwitchExtensionPortFeature
    {
    }
    function Get-VMSystemSwitchExtensionSwitchFeature
    {
    }
} | Import-Module -Force

Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    function Set-SCVMMServer
    {
        param
        (
           $VMMServer
        )
    }
    function Get-SCVMMServer
    {
        param
        (
            $ComputerName
        )
        return $true
    }
    Export-ModuleMember -Function *
} | Import-Module -Force

Describe "MSFT_xSCVMMSwitchExtension Tests" {

    $global:FunctionCounter = 0
    $global:DefaultUPP = "TestUPP"
    $global:DefaultVSwitch = "External_Switch"
    $global:DefaultLSwitch = "Test_Logical_Switch"
    $global:DefaultSwitchID = "switch-guid"
    $global:DefaultPortID = "port-guid"
    $global:DefaultPortName = "TestUPP_guid"
    $global:DefaultSession = (New-PSSession .)
    $global:ParamSet = `
    @{
        VirtualSwitch = $DefaultVSwitch
        VMMLogicalSwitch = $DefaultLSwitch
        VMMUplinkPortProfile = $DefaultPortName
        VMMServer = "TESTVMM01"
    }
    
    AfterEach {
        $global:FunctionCounter = 0
    }
    
    Context "Get Succeeds" {
        Mock -ModuleName MSFT_xSCVMMSwitchExtension New-PSSession -Verifiable {
            return $DefaultSession
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension -CommandName Invoke-Command -Verifiable {
            $true
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMSwitch -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultVSwitch
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMMSwitchMap -Verifiable {
            $map = @{}
            $map["LogicalSwitchID"] = $DefaultSwitchID
            $map["UplinkPortProfileSetID"] = $DefaultPortID
            $map["UplinkPortProfileSetName"] = $DefaultPortName
            return $map
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMSwitchExtensionSwitchFeature -Verifiable {
            $Settings = New-Object PSObject -Property @{
                LogicalSwitchId = $DefaultSwitchID
                LogicalSwitchName = $DefaultVSwitch
            }
            $Item = New-Object PSObject -Property @{
                SettingData = $Settings
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMSwitchExtensionPortFeature -Verifiable {
            $Settings = New-Object PSObject -Property @{
                PortProfileSetId = $DefaultPortID
                PortProfileSetName = $DefaultPortName
            }
            $Item = New-Object PSObject -Property @{
                SettingData = $Settings
            }
            return $Item
        }
        
        It "Get-TargetResource finds the switch extension matches what is expected" {
            $result = Get-TargetResource @ParamSet -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.VMMLogicalSwitch | Should Be $DefaultVSwitch
            $result.VMMLogicalSwitchId | Should Be $DefaultSwitchID
            $result.VMMUplinkPortProfileName | Should Be $DefaultPortName
            $result.VMMUplinkPortProfileId | Should Be $DefaultPortID
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Succeeds" {
        Mock -ModuleName MSFT_xSCVMMSwitchExtension New-PSSession -Verifiable {
            return $DefaultSession
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension -CommandName Invoke-Command -Verifiable {
            $true
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMSwitch -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultVSwitch
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMMSwitchMap -Verifiable {
            $map = @{}
            $map["LogicalSwitchID"] = $DefaultSwitchID
            $map["UplinkPortProfileSetID"] = $DefaultPortID
            $map["UplinkPortProfileSetName"] = $DefaultPortName
            return $map
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMSwitchExtensionSwitchFeature -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMSwitchExtension Get-VMSwitchExtensionPortFeature -Verifiable {
        }
        
        It "Get-TargetResource is unable to find any switch extension" {
            $result = Get-TargetResource @ParamSet -Verbose -Debug:$false
            $result.Ensure | Should Be "Absent"
        }
    }
}

Get-Module -Name Hyper-V | Remove-Module
Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name MSFT_xSCVMMSwitchExtension | Remove-Module
