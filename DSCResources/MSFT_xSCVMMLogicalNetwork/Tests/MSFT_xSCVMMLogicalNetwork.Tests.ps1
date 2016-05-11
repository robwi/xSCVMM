<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMLogicalNetwork.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMLogicalNetwork.psm1"
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
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function Get-SCLogicalNetwork
    {
        param
        (
            [System.String]$Name,
            [System.String]$VMMServer
        )
    }
    function New-SCLogicalNetwork
    {
        param
        (
            [Parameter(Mandatory = $true)][System.String]$Name,
            [System.String]$Description,
            [System.Boolean]$EnableNetworkVirtualization,
            [System.Boolean]$UseGRE,
            [System.Boolean]$IsPVLAN,
            [System.Boolean]$LogicalNetworkDefinitionIsolation,
            [System.String]$VMMServer,
            [switch]$RunAsynchronously
        )
    }
    function Set-SCLogicalNetwork
    {
        param
        (
            [Parameter(Mandatory = $true)]$LogicalNetwork,
            [System.String]$Name,
            [System.String]$Description,
            [System.Boolean]$EnableNetworkVirtualization,
            [System.Boolean]$UseGRE,
            [System.Boolean]$IsPVLAN,
            [System.Boolean]$LogicalNetworkDefinitionIsolation,
            [System.String]$VMMServer,
            [switch]$RunAsynchronously
        )
    }
    function Remove-SCLogicalNetwork
    {
    }
    function Get-SCLogicalNetworkDefinition
    {
        param
        (
            [Parameter(Mandatory = $false)]$LogicalNetwork
        )
    }
    function Get-SCStaticIPAddressPool
    {
        param
        (
            [Parameter(Mandatory = $false)]$LogicalNetworkDefinition
        )
    }
    function Remove-SCStaticIPAddressPool
    {
        param
        (
            [Parameter(Mandatory = $true)]$StaticIPAddressPool
        )
    }
    function Remove-SCLogicalNetworkDefinition
    {
        param
        (
            [Parameter(Mandatory = $true)]$LogicalNetworkDefinition
        )
    }
    function Get-SCVMNetwork
    {
    }
    function Remove-SCVMNetwork
    {
        param
        (
            [Parameter(Mandatory = $true)]$VMNetwork
        )
    }
    function Get-SCVMMServer
    {
        param
        (
            [Parameter(Mandatory = $true)]
            [System.String]
            $ComputerName
        )
        return $true
    }
    Export-ModuleMember -Function *
} | Import-Module -Force

Describe "MSFT_xSCVMMLogicalNetwork Tests" {

    $global:DefaultDescription = "Logical Network Description"
    $global:GetLogicalNetworkCount = 0
    
    AfterEach {
        $global:GetLogicalNetworkCount = 0
    }
    
    Context "Get Present - Single type with NVGRE" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Description = $DefaultDescription
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
            }
            $returnValue
        }
        It "Get-TargetResource when Logical Network exists with Network Virtualization enabled" {
            $Name = 'LN_Single_NVGRE'
            $result = Get-TargetResource -Name $Name -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.Description | Should Be $DefaultDescription
            $result.NetworkType | Should Be "Single"
            $result.EnableNetworkVirtualization | Should Be $true
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present - Single type without NVGRE" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Description = $DefaultDescription
                IsLogicalNetworkDefinitionIsolated = $false
                IsPVLAN = $false
                NetworkVirtualizationEnabled = $false
            }
            $returnValue
        }
        It "Get-TargetResource when Logical Network exists with Network Virtualization disabled" {
            $Name = 'LN_Single_NoNVGRE'
            $result = Get-TargetResource -Name $Name -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.Description | Should Be $DefaultDescription
            $result.NetworkType | Should Be "Single"
            $result.EnableNetworkVirtualization | Should Be $false
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present - VLAN type" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Description = $DefaultDescription
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
                NetworkVirtualizationEnabled = $false
            }
            $returnValue
        }
        It "Get-TargetResource when Logical Network of type VLAN exists" {
            $Name = 'LN_VLAN'
            $result = Get-TargetResource -Name $Name -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.Description | Should Be $DefaultDescription
            $result.NetworkType | Should Be "VLAN"
            $result.EnableNetworkVirtualization | Should Be $false
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present - PVLAN type" {
    
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Description = $DefaultDescription
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
                NetworkVirtualizationEnabled = $false
            }
            $returnValue
        }
        It "Get-TargetResource when Logical Network of type PVLAN exists" {
            $Name = 'LN_VLAN'
            $result = Get-TargetResource -Name $Name -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.Description | Should Be $DefaultDescription
            $result.NetworkType | Should Be "PVLAN"
            $result.EnableNetworkVirtualization | Should Be $false
            Assert-VerifiableMocks
        }
        
    }
    
    Context "Get Absent" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable {
                $returnValue = $null
                $returnValue
        }
        It "Get-TargetResource when Logical Network does not exist" {
            $Name = 'LN_Absent'
            $result = Get-TargetResource -Name $Name -Verbose
            $result.Ensure | Should Be "Absent"
            $result.Name | Should Be $Name
            Assert-VerifiableMocks
        }
    }
    
    # Test-TargetResource is always called after Set-TargetResource to insure the settings were applied successfully
    
    Context "Test/Set Present - Change existing Single type with NVGRE disabled when it should be enabled" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable {
            If ($global:GetLogicalNetworkCount -lt 2)
            {
                # The first time Get-SCLogicalNetwork is called from the Set and Test Functions, NetworkVirtualizationEnabled is $false
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $false
                    IsPVLAN = $false
                    NetworkVirtualizationEnabled = $false
                }
            }
            Else
            {
                # After the Set function, this has changed to $true
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $false
                    IsPVLAN = $false
                    NetworkVirtualizationEnabled = $true
                }
            }
            $global:GetLogicalNetworkCount++
            return $returnValue
        }
        It "Set-TargetResource when Logical Network exists but NetworkVirtualization needs to be changed" {
            $Ensure = "Present"
            $Name = 'LN_Existing_Single_NVGRE'
            $NetworkType = "Single"
            $EnableNetworkVirtualization = $true
            
            # Test should be $false the first time since we need to change a property
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -EnableNetworkVirtualization $EnableNetworkVirtualization -Verbose
            $result | Should Be $false
            
            # Set does not return anything, it relies on Test to insure the settings were set correctly
            Set-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -EnableNetworkVirtualization $EnableNetworkVirtualization -Verbose
            
            # Now Test should be $true
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -EnableNetworkVirtualization $EnableNetworkVirtualization -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set Present - Change Description of existing PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable { 
            If ($global:GetLogicalNetworkCount -lt 2)
            {
                $returnValue = `
                @{
                    Description = "This description should be changed"
                    IsLogicalNetworkDefinitionIsolated = $true
                    IsPVLAN = $true
                    NetworkVirtualizationEnabled = $false
                }
            }
            Else
            {
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $true
                    IsPVLAN = $true
                    NetworkVirtualizationEnabled = $false
                }
            }
            $global:GetLogicalNetworkCount++
            $returnValue
        }
        It "Set-TargetResource when Logical Network exists but Description needs to be changed" {
            $Ensure = "Present"
            $Name = 'LN_Existing_PVLAN'
            $NetworkType = "PVLAN"

            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -Verbose
            
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set Present - Change type of existing Logical Network from VLAN to PVLAN" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable { 
            If ($global:GetLogicalNetworkCount -lt 2)
            {
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $true
                    IsPVLAN = $false
                    NetworkVirtualizationEnabled = $false
                }
            }
            Else
            {
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $true
                    IsPVLAN = $true
                    NetworkVirtualizationEnabled = $false
                }
            }
            $global:GetLogicalNetworkCount++
            $returnValue
        }
        It "Set-TargetResource when Logical Network exists but type needs to change from VLAN to PVLAN" {
            $Ensure = "Present"
            $Name = 'LN_Existing_VLAN'
            $NetworkType = "PVLAN"

            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -Verbose
            
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set Present - Create new Single type with NVGRE enabled" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable { 
            If ($global:GetLogicalNetworkCount -lt 2)
            {
                $returnValue = $null
            }
            Else
            {
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $false
                    IsPVLAN = $false
                    NetworkVirtualizationEnabled = $true
                }
            }
            $global:GetLogicalNetworkCount++
            $returnValue
        }
        It "Set-TargetResource when Logical Network does not exist" {
            $Ensure = "Present"
            $Name = 'LN_New_Single_NVGRE'
            $NetworkType = "Single"
            $EnableNetworkVirtualization = $true
            
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -EnableNetworkVirtualization $EnableNetworkVirtualization -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -EnableNetworkVirtualization $EnableNetworkVirtualization -Verbose
            
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -NetworkType $NetworkType -Description $DefaultDescription -EnableNetworkVirtualization $EnableNetworkVirtualization -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set Absent - Remove an existing Logical Network" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetwork Get-SCLogicalNetwork -Verifiable { 
            If ($global:GetLogicalNetworkCount -lt 2)
            {
                $returnValue = `
                @{
                    Description = $DefaultDescription
                    IsLogicalNetworkDefinitionIsolated = $false
                    IsPVLAN = $false
                    NetworkVirtualizationEnabled = $true
                }
            }
            Else
            {
                $returnValue = $null
            }
            $global:GetLogicalNetworkCount++
            $returnValue
        }
        It "Set-TargetResource when Logical Network exists and should be removed" {
            $Ensure = "Absent"
            $Name = 'LN_Absent'
            
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -Ensure $Ensure -Verbose
            
            $result = Test-TargetResource -Name $Name -Ensure $Ensure -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
}

Get-Module -Name VirtualMachineManager | Remove-Module
