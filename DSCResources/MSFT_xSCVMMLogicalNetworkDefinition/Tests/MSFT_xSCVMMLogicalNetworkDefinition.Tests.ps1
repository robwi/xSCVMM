<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMLogicalNetworkDefinition.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMLogicalNetworkDefinition.psm1"
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
    function New-SCSubnetVLan
    {
        param
        (
            [System.String]$Subnet,
            [System.String]$VLanID,
            [System.String]$SecondaryVLanID
        )
        If ($VLanID -ne 0) { $IsVLanEnabled = $true } Else { $IsVLanEnabled = $false }
        If ($IsSecondaryVLanEnabled -ne 0) { $IsSecondaryVLanEnabled = $true } Else { IsSecondaryVLanEnabled = $false}
        $returnValue = @{
            Subnet = $Subnet
            VLanID = $VLanID
            SecondaryVLanID = $SecondaryVLanID
            IsVLanEnabled = $IsVLanEnabled
            IsSecondaryVLanEnabled = $IsSecondaryVLanEnabled
            SupportsDHCP = $true
            IsAssignedToVMSubnet = $false
        }
        return $returnValue
    }
    function Get-SCVMHostGroup
    {
        param
        (
            [Parameter(Mandatory = $true)][System.String]$Name
        )
    }
    function Get-SCLogicalNetworkDefinition
    {
        param
        (
            [Parameter(Mandatory = $true)][System.String]$Name,
            [Parameter(Mandatory = $true)]$LogicalNetwork,
            [System.String]$VMMServer,
            [switch]$RunAsynchronously
        )
    }
    function New-SCLogicalNetworkDefinition
    {
    }
    function Set-SCLogicalNetworkDefinition
    {
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

Describe "MSFT_xSCVMMLogicalNetworkDefinition Tests" {

    $global:GetLogicalNetworkDefCount = 0
    $global:DefaultLogicalNetworkName = "LN_Test"
    
    AfterEach {
        $global:GetLogicalNetworkDefCount = 0
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
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
        It "Get-TargetResource when Logical Network Definition exists with a single Site" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Exists'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.HostGroups | Should Match "All Hosts"
            $result.SubnetVlan | Should Match "192.168.0.0/24-0-0"
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                HostGroups = @(
                    @{
                        Name = "Host Group A"
                    },
                    @{
                        Name = "Host Group B"
                    }
                )
                SubnetVLans = @(
                    @{
                       Subnet = "192.168.10.0/24"
                       VLanID = 10
                       SecondaryVLanID = 0
                    },
                    @{
                       Subnet = "192.168.20.0/24"
                       VLanID = 20
                       SecondaryVLanID = 0
                    }
                )
            }
            return $returnValue
        }
        It "Get-TargetResource when Logical Network Definition exists with multiple Sites" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Exists'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.HostGroups[0] | Should Be "Host Group A"
            $result.HostGroups[1] | Should Be "Host Group B"
            $result.SubnetVlan[0] | Should Be "192.168.10.0/24-10-0"
            $result.SubnetVlan[1] | Should Be "192.168.20.0/24-20-0"
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                HostGroups = @()
                SubnetVLans = @()
            }
            return $returnValue
        }
        It "Get-TargetResource when Logical Network Definition exists but no Sites are defined" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Exists'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.HostGroups | Should BeNullOrEmpty
            $result.SubnetVlan | Should BeNullOrEmpty
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Absent" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            return $null
        }
        It "Get-TargetResource when Logical Network exists but Definition does not exist" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Absent'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose
            $result.Ensure | Should Be "Absent"
            $result.HostGroups | Should BeNullOrEmpty
            $result.SubnetVlan | Should BeNullOrEmpty
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Absent" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            return $null
        }
        It "Get-TargetResource when Logical Network does not exist" {
            $LogicalNetwork = 'LN_Absent'
            $Name = 'LND_Name'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork
            $result.Ensure | Should Be "Absent"
            $result.HostGroups | Should BeNullOrEmpty
            $result.SubnetVlan | Should BeNullOrEmpty
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new Logical Network Definition" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            $returnValue = @{Name=$Name}
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCVMHostGroup -Verifiable {
            return $Name
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition New-SCLogicalNetworkDefinition -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            If ($global:GetLogicalNetworkDefCount -lt 2)
            {
                $returnValue = $null
            }
            Else
            {
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
            }
            $global:GetLogicalNetworkDefCount++
            return $returnValue
        }
        It "Set-TargetResource when Logical Network does not yet exist" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Create_New'
            $SubnetVlan = @("192.168.0.0/24-0-0")
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Add missing Subnet to existing Logical Network Definition" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            $returnValue = @{Name=$Name}
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Set-SCLogicalNetworkDefinition -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            If ($global:GetLogicalNetworkDefCount -lt 2)
            {
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
            }
            Else
            {
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
                        },
                        @{
                            Subnet = "192.168.10.0/24"
                            VLanID = 10
                            SecondaryVLanID = 0
                        }
                    )
                }
            }
            $global:GetLogicalNetworkDefCount++
            return $returnValue
        }
        It "Set-TargetResource when Logical Network exist but Site needs to be added" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Add_Site'
            $SubnetVlan = @("192.168.0.0/24-0-0","192.168.10.0/24-10-0")
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Add missing Host Group to existing Logical Network Definition" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            $returnValue = @{Name=$Name}
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCVMHostGroup -Verifiable {
            return $Name
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Set-SCLogicalNetworkDefinition -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            If ($global:GetLogicalNetworkDefCount -lt 2)
            {
                $returnValue = `
                @{
                    Name = $Name
                    LogicalNetwork = $LogicalNetwork
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
            }
            Else
            {
                $returnValue = `
                @{
                    HostGroups = @(
                        @{
                            Name = "All Hosts"
                        },
                        @{
                            Name = "Group To Add"
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
            }
            $global:GetLogicalNetworkDefCount++
            return $returnValue
        }
        It "Set-TargetResource when Logical Network exist but Subnet needs to be added to existing Site" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Add_Subnet'
            $SubnetVlan = @("192.168.0.0/24-0-0")
            $HostGroups = @("All Hosts","Group To Add")
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -HostGroups $HostGroups -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -HostGroups $HostGroups -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -HostGroups $HostGroups -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Remove unwanted Host Group and Subnet" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            $returnValue = @{Name=$Name}
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCVMHostGroup -Verifiable {
            return $Name
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Set-SCLogicalNetworkDefinition -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            If ($global:GetLogicalNetworkDefCount -lt 2)
            {
                $returnValue = `
               @{
                    Name = $Name
                    LogicalNetwork = $LogicalNetwork
                    HostGroups = @(
                        @{
                            Name = "All Hosts"
                        },
                        @{
                            Name = "Remove This Group"
                        }
                    )
                    SubnetVLans = @(
                        @{
                            Subnet = "192.168.0.0/24"
                            VLanID = 0
                            SecondaryVLanID = 0
                        },
                        @{
                            Subnet = "192.168.10.0/24"
                            VLanID = 10
                            SecondaryVLanID = 0
                        }
                    )
                }
            }
            Else
            {
                $returnValue = `
                @{
                    Name = $Name
                    LogicalNetwork = $LogicalNetwork
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
            }
            $global:GetLogicalNetworkDefCount++
            return $returnValue
        }
        It "Set-TargetResource when StrictConfiguration forces removal of unwanted configurations" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_StrictConfig'
            $SubnetVlan = @("192.168.0.0/24-0-0")
            $HostGroups = @("All Hosts")
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -HostGroups $HostGroups -StrictConfiguration $true -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -HostGroups $HostGroups -StrictConfiguration $true -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -HostGroups $HostGroups -StrictConfiguration $true -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Remove unwanted Network Site" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            $returnValue = @{Name=$Name}
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Remove-SCLogicalNetworkDefinition -Verifiable {
            return $true
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            If ($global:GetLogicalNetworkDefCount -lt 2)
            {
                $returnValue = `
                @(
                    @{
                        Name = $Name
                        LogicalNetwork = $LogicalNetwork
                        HostGroups = @(
                            @{
                                Name = "All Hosts"
                            }
                        )
                        SubnetVLans = @(
                            @{
                                Subnet = "10.0.0.0/16"
                                VLanID = 0
                                SecondaryVLanID = 0
                            }
                        )
                    }
                )
            }
            Else
            {
                $returnValue = $null
            }
            $global:GetLogicalNetworkDefCount++
            return $returnValue
        }
        It "Set-TargetResource remove Logical Network Definition" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Remove'
            $Ensure = "Absent"
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Ensure $Ensure -StrictConfiguration $true -Verbose
            $result | Should Be $false
            
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Ensure $Ensure -StrictConfiguration $true -Verbose -Debug:$false
            
            $result = Test-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Ensure $Ensure -StrictConfiguration $true -Verbose
            $result | Should Be $true
            
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails - Invalid Subnet/VLAN" {
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetwork -Verifiable {
            $returnValue = @{Name=$Name}
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCVMHostGroup -Verifiable {
            return $Name
        }
        Mock -ModuleName MSFT_xSCVMMLogicalNetworkDefinition Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = $null
            return $returnValue
        }
        It "Set-TargetResource when IPv4 address contains octet that is out of range" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("256.168.0.0/24")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when IPv4 contains non-numeric characters" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("A.B.C.D/24")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when IP address is '0'" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("0/24")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when IP address is '1'" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("1/24")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when subnet is missing the prefix" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when prefix value for IPv4 address is too small" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0/2")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when prefix value for IPv4 address is too large" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0/32")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when prefix is non-numeric" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0/X")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when subnet contains extra '/'" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0//24")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when subnet contains '-' instead of '/'" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0-24")
            $error = "The Subnet '192.168.0.0' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when invald IPv6 address" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("FFFX:4898:f0:22::/64")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when IPv6 address is missing prefix" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("2001:4898:f0:22::/")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when prefix value for IPv6 address is to small" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("2001:4898:f0:22::/32")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when prefix value for IPv6 address is to large" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("2001:4898:f0:22::/128")
            $error = "The Subnet '$($SubnetVlan)' contains an invalid IP Address/Prefix value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VLAN is non-numeric" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0/24-A-0")
            $error = "The VlanId '$($SubnetVlan.Split('-')[1])' is not a valid value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VLAN is too large" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'LND_Fail_Create_New'
            $SubnetVlan = @("192.168.0.0/24-9999-0")
            $error = "The VlanId '$($SubnetVlan.Split('-')[1])' is not a valid value."
            
            { Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -SubnetVlan $SubnetVlan -Debug:$false } | Should Throw $error
            
            Assert-VerifiableMocks
        }
    }
    
}

Get-Module -Name VirtualMachineManager | Remove-Module
