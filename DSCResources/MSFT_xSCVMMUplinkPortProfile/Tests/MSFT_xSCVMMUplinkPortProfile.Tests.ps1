<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMUplinkPortProfile.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMUplinkPortProfile.psm1"
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
    }
    function Get-SCLogicalNetworkDefinition
    {
        param
        (
            $Name,
            $LogicalNetwork
        )
    }
    Export-ModuleMember -Function *
} | Import-Module -Force

Describe "MSFT_xSCVMMUplinkPortProfile Tests" {

    $global:FunctionCounter = 0
    $global:DefaultName = "TestUPP"
    $global:DefaultSite = "TestSite_0;TestNetwork"
    $global:DefaultSiteObj = @{Name="TestSite_0";LogicalNetwork="TestNetwork"}
    $global:DefaultLBA = "Dynamic"
    $global:DefaultTM = "LACP"
    
    AfterEach {
        $global:FunctionCounter = 0
    }
    
    Context "Get Succeeds" {
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCNativeUplinkPortProfile -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultName
                Description = $DefaultName
                LBFOLoadBalancingAlgorithm = $DefaultLBA
                LBFOTeamMode = $DefaultTM
                EnableNetworkVirtualization = $false
                LogicalNetworkDefinitions = @($DefaultSiteObj)
            }
            return $Item
        }
        It "Get-TargetResource finds the Uplink Port Profile specified" {
            $result = Get-TargetResource -Name $DefaultName -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $DefaultName
            $result.Description | Should Be $DefaultName
            $result.LoadBalancingAlgorithm | Should Be $DefaultLBA
            $result.TeamMode | Should Be $DefaultTM
            $result.NetworkSite | Should Be $DefaultSite
            $result.NetworkVirtualization | Should Be $false
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Succeeds" {
        It "Get-TargetResource is unable to find the Uplink Port Profile specified" {
            $result = Get-TargetResource -Name $DefaultName -Verbose -Debug:$false
            $result.Ensure | Should Be "Absent"
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCNativeUplinkPortProfile -Verifiable {
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = $DefaultName
                    LBFOLoadBalancingAlgorithm = $DefaultLBA
                    LBFOTeamMode = $DefaultTM
                    EnableNetworkVirtualization = $false
                    LogicalNetworkDefinitions = @($DefaultSiteObj)
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @(
                    @{
                       Subnet = "192.168.0.0/24"
                       VLanID = 0
                       SecondaryVLanID = 0
                    }
                )
            }
            return $returnValue
        }
        It "Set-TargetResource is able to create a new Uplink Port Profile" {
        
            Set-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $DefaultSite -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $DefaultSite -Verbose -Debug:$false
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCNativeUplinkPortProfile -Verifiable {
            If ($global:FunctionCounter -ge 2)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = $DefaultName
                    LBFOLoadBalancingAlgorithm = $DefaultLBA
                    LBFOTeamMode = $DefaultTM
                    EnableNetworkVirtualization = $false
                    LogicalNetworkDefinitions = @($DefaultSiteObj)
                }
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = "Should Change"
                    LBFOLoadBalancingAlgorithm = "HostDefault"
                    LBFOTeamMode = "SwitchIndependent"
                    EnableNetworkVirtualization = $true
                    LogicalNetworkDefinitions = @(@{Name="ExtraSite_1";LogicalNetwork="TestNetwork"})
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @(
                    @{
                       Subnet = "192.168.0.0/24"
                       VLanID = 0
                       SecondaryVLanID = 0
                    }
                )
            }
            return $returnValue
        }
        It "Set-TargetResource is able to modify an existing Uplink Port Profile" {
        
            $result = Test-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $DefaultSite -Verbose -Debug:$false
            $result | Should Be $false
            
            Set-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $DefaultSite -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $DefaultSite -Verbose -Debug:$false
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCNativeUplinkPortProfile -Verifiable {
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = $DefaultName
                    LBFOLoadBalancingAlgorithm = $DefaultLBA
                    LBFOTeamMode = $DefaultTM
                    EnableNetworkVirtualization = $false
                    LogicalNetworkDefinitions = @($DefaultSiteObj)
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        It "Set-TargetResource fails when Network Site string is not formatted correctly" {
            $Site = "Bad-Format,LogicalNetwork"
            $BadSite =@($Site)
            {Set-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $BadSite -Verbose -Debug:$false} | Should Throw "Network Site '$($Site)' is not properly formatted. Should be like: 'SiteName;LogicalNetwork'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMUplinkPortProfile Get-SCNativeUplinkPortProfile -Verifiable {
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $DefaultName
                    Description = $DefaultName
                    LBFOLoadBalancingAlgorithm = $DefaultLBA
                    LBFOTeamMode = $DefaultTM
                    EnableNetworkVirtualization = $false
                    LogicalNetworkDefinitions = @($DefaultSiteObj)
                }
            }
            $global:FunctionCounter++
            return $Item
        }
        It "Set-TargetResource fails when a specified Network Site cannot be found" {
            $SiteName = "MissingSite_0"
            $LogicalNetwork = "LogicalNetwork"
            $Site = $SiteName + ';' + $LogicalNetwork
            $MissingSite =@($Site)
            {Set-TargetResource -Name $DefaultName -Description $DefaultName -NetworkSite $MissingSite -Verbose -Debug:$false} | Should Throw "Unable to find Network Site '$($SiteName)' on Logical Network '$($LogicalNetwork)'."
            Assert-VerifiableMocks
        }
    }
    
}

Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name MSFT_xSCVMMUplinkPortProfile | Remove-Module
