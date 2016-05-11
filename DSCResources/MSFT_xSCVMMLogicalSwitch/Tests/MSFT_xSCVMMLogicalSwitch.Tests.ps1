<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMLogicalSwitch.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMLogicalSwitch.psm1"
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
    function Get-SCLogicalSwitch
    {
        param
        (
            $Name,
            $VMMServer
        )
    }
    function New-SCLogicalSwitch
    {
    }
    function Set-SCLogicalSwitch
    {
    }
    function Get-SCLogicalNetworkDefinition
    {
        param
        (
            $Name,
            $LogicalNetwork,
            $VMMServer,
            $RunAsynchronously
        )
    }
    function Get-SCNativeUplinkPortProfile
    {
        param
        (
            $VMMServer,
            $Name
        )
    }
    function New-SCNativeUplinkPortProfile
    {
        param
        (
            $VMMServer,
            $Name,
            $Description,
            $LBFOLoadBalancingAlgorithm,
            $LBFOTeamMode,
            $LogicalNetworkDefinition,
            $EnableNetworkVirtualization,
            $RunAsynchronously
        )
    }
    function Set-SCNativeUplinkPortProfile
    {
        param
        (
            $VMMServer,
            $Name,
            $Description,
            $LBFOLoadBalancingAlgorithm,
            $LBFOTeamMode,
            $LogicalNetworkDefinition,
            $EnableNetworkVirtualization,
            $RunAsynchronously
        )
    }
    function Remove-SCNativeUplinkPortProfile
    {
        param
        (
            $NativeUplinkPortProfile
        )
    }
    function Get-SCUplinkPortProfileSet
    {
        param
        (
            $LogicalSwitch
        )
    }
    function Get-SCVirtualNetworkAdapterPortProfileSet
    {
        param
        (
            $LogicalSwitch
        )
    }
    function Get-SCLogicalNetworkDefinition
    {
        param
        (
            $Name,
            $LogicalNetwork
        )
    }
    function Get-SCVirtualSwitchExtension
    {
        param
        (
            $Name
        )
    }
    Export-ModuleMember -Function *
} | Import-Module -Force

Describe "MSFT_xSCVMMLogicalSwitch Tests" {

    $global:FunctionCounter = 0
    $global:DefaultName = "TestSwitch"
    $global:DefaultMode = "Team"
    $global:DefaultVSE = "Microsoft Windows Filtering Platform"
    $global:DefaultVSEObj = New-Object PSObject -Property @{Name=$DefaultVSE}
    
    AfterEach {
        $global:FunctionCounter = 0
    }
    
    Context "Get Succeeds" {
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCLogicalSwitch -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultName
                Description = $DefaultName
                EnableSriov = $false
                UplinkMode = $DefaultMode
                VirtualSwitchExtensions = @($DefaultVSEObj)
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCUplinkPortProfileSet -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCVirtualNetworkAdapterPortProfileSet -Verifiable {
        }
        
        It "Get-TargetResource is able to find the Logical Switch specified" {
            $result = Get-TargetResource -Name $DefaultName -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $DefaultName
            $result.Description | Should Be $DefaultName
            $result.EnableSRIOV | Should Be $false
            $result.UplinkMode | Should Be $DefaultMode
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Succeeds" {
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCLogicalSwitch -Verifiable {
        }
        It "Get-TargetResource is unable to find the Logical Switch specified" {
            $result = Get-TargetResource -Name $DefaultName -Verbose -Debug:$false
            $result.Ensure | Should Be "Absent"
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCLogicalSwitch -Verifiable {
            If ($global:FunctionCounter -gt 0)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = $DefaultName
                    EnableSriov = $false
                    UplinkMode = $DefaultMode
                    VirtualSwitchExtensions = @($DefaultVSEObj)
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCVirtualSwitchExtension -Verifiable {
            param($Name)
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCUplinkPortProfileSet -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCVirtualNetworkAdapterPortProfileSet -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch New-SCLogicalSwitch -Verifiable {
            return $DefaultName
        }
        It "Set-TargetResource is able to create a new Logical Switch" {
            Set-TargetResource -Name $DefaultName -SwitchExtensions @($DefaultVSE) -Verbose -Debug:$false
            $result = Test-TargetResource -Name $DefaultName -SwitchExtensions @($DefaultVSE) -Verbose -Debug:$false
            $result | Should Be $true
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCLogicalSwitch -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = $DefaultName
                    EnableSriov = $false
                    UplinkMode = $DefaultMode
                    VirtualSwitchExtensions = @($DefaultVSEObj)
                }
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = "Wrong Description"
                    EnableSriov = $false
                    UplinkMode = "NoTeam"
                    VirtualSwitchExtensions = @()
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCVirtualSwitchExtension -Verifiable {
            param($Name)
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCUplinkPortProfileSet -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCVirtualNetworkAdapterPortProfileSet -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Set-SCLogicalSwitch -Verifiable {
            return $DefaultName
        }
        It "Set-TargetResource is able to modify an existing Logical Switch" {
            
            $result = Test-TargetResource -Name $DefaultName -SwitchExtensions @($DefaultVSE) -Verbose -Debug:$false
            $result | Should Be $false
            
            Set-TargetResource -Name $DefaultName -Verbose -SwitchExtensions @($DefaultVSE) -Debug:$false
            
            $result = Test-TargetResource -Name $DefaultName -SwitchExtensions @($DefaultVSE) -Verbose -Debug:$false
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCLogicalSwitch -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCVirtualSwitchExtension -Verifiable {
        }
        It "Set-TargetResource fails because an invalid Switch Extension is specified" {
            $Extension = "Missing Extension"
            {Set-TargetResource -Name $DefaultName -SwitchExtensions @($Extension) -Verbose -Debug:$false} | Should Throw "A Virtual Switch Extension named '$($Extension)' cannot be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMLogicalSwitch Get-SCLogicalSwitch -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultName
                Description = $DefaultName
                EnableSriov = $true
                UplinkMode = $DefaultMode
                VirtualSwitchExtensions = @($DefaultVSEObj)
            }
            return $Item
        }
        It "Set-TargetResource fails because you cannot change the SR-IOV setting after a Logical Switch has been created" {
            {Set-TargetResource -Name $DefaultName -Verbose -Debug:$false} | Should Throw "The SR-IOV setting cannot be changed once the Logical Switch has been created."
            Assert-VerifiableMocks
        }
    }
    
    #
    # Should Throw "Virtual Port string is not properly formatted. Should be in the format: 'VirtualPortName;PortClassification;NetworkAdapterPortProfile'."
}

Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name MSFT_xSCVMMLogicalSwitch | Remove-Module
