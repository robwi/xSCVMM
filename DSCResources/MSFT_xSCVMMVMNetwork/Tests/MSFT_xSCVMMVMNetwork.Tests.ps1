<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMVMNetwork.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMVMNetwork.psm1"
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
        param
        (
            [System.Boolean]$Confirm
        )
    }
    function New-SCVMSubnet
    {
        param
        (
            $Name,
            $LogicalNetworkDefinition,
            $SubnetVLan,
            $VMNetwork,
            $VMMServer,
            [switch]$RunAsynchronously
        )
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
            [Parameter(Mandatory = $true)]$LogicalNetwork,
            [System.String]$Name,
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
            $LogicalNetworkDefinition
        )
    }
    function Remove-SCStaticIPAddressPool
    {
        param
        (
            $StaticIPAddressPool,
            [System.Boolean]$Confirm
        )
    }
    function Get-SCIPAddress
    {
    }
    function Revoke-SCIPAddress
    {
    }
    function Remove-SCLogicalNetworkDefinition
    {
        param
        (
            $LogicalNetworkDefinition,
            [System.Boolean]$Confirm
        )
    }
    function Get-SCVMNetwork
    {
        param
        (
            $Name,
            $LogicalNetwork,
            $VMMServer
        )
    }
    function New-SCVMNetwork
    {
        param
        (
            $Name,
            $Description,
            $LogicalNetwork,
            [ValidateSet("External","NoIsolation","VLANNetwork","WindowsNetworkVirtualization")][System.String]$IsolationType,
            $VMMServer
        )
    }
    function Remove-SCVMNetwork
    {
        param
        (
            $VMNetwork,
            [System.Boolean]$Confirm
        )
    }
    function Get-SCVirtualNetworkAdapter
    {
        param
        (
            [switch]$All
        )
    }
    function Set-SCVirtualNetworkAdapter
    {
        param
        (
            [switch]$NoLogicalNetwork,
            [switch]$NoConnection,
            [switch]$NoPortClassification
        )
    }
    function Get-SCVMSubnet
    {
        param
        (
            $VMNetwork
        )
    }
    function Remove-SCVMSubnet
    {
        param
        (
            [System.Boolean]$Confirm
        )
    }
    function Get-SCVMNetworkGateway
    {
        param
        (
            $VMNetwork
        )
    }
    function Remove-SCVMNetworkGateway
    {
        param
        (
            [System.Boolean]$Confirm
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

Describe "MSFT_xSCVMMVMNetwork Tests" {

    $global:FunctionCounter = 0
    $global:DefaultLogicalNetworkName = "LN_Test"
    $global:DefaultLogicalNetworkDef = "LND_Test"
    $global:DefaultDescription = "VM Network Test"
    
    $global:DefaultSubnetVlan = `
    @{
        Subnet = "192.168.0.0/24"
        VLanID = 0
        SecondaryVLanID = 0
    }
    $global:DefaultSubnetVlanString = "Test-SubnetVlan;192.168.0.0/24-0-0"
    
    $global:DefaultIPv6SubnetVlan = `
    @{
        Subnet = "2001:4898:f0:22::/64"
        VLanID = 0
        SecondaryVLanID = 0
    }
    $global:DefaultIPv6SubnetVlanString = "Test-IPv6SubnetVlan;2001:4898:f0:22::/64-0-0"
    
    $global:UnusedSubnetVlan = `
    @{
        Subnet = "10.10.1.0/24"
        VLanID = 2
        SecondaryVLanID = 0
    }
    $global:DefaultVMSubnet = `
    @{
        Name = "Test-SubnetVlan"
        SubnetVLans = $DefaultSubnetVlan
    }
    $global:DefaultIPv6VMSubnet = `
    @{
        Name = "Test-IPv6SubnetVlan"
        SubnetVLans = $DefaultIPv6SubnetVlan
    }
    
    AfterEach {
        $global:FunctionCounter = 0
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            return @{Name = $Name}
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                PAIPAddressPoolType = ""
                CAIPAddressPoolType = ""
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource when VM Network exists" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Exists'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $DefaultLogicalNetworkName -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.VMSubnets | Should Match $DefaultSubnetVlanString
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Absent" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            return @{Name = $Name}
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Get-TargetResource when VM Network does not exist" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Absent'
            $result = Get-TargetResource -Name $Name -LogicalNetwork $DefaultLogicalNetworkName -Verbose -Debug:$false
            $result.Ensure | Should Be "Absent"
            $result.Description | Should BeNullOrEmpty
            $result.LogicalNetwork | Should BeNullOrEmpty
            $result.PAIPAddressPoolType | Should BeNullOrEmpty
            $result.CAIPAddressPoolType | Should BeNullOrEmpty
            $result.VMSubnet | Should BeNullOrEmpty
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            return @{Name = $Name}
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            $returnValue = `
           @(
                @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                },
                @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
            )
            return $returnValue
        }
        It "Get-TargetResource fails because mulitple matching VM Networks were found" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Exists'
            {Get-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose -Debug:$false} | Should Throw "Found multiple VM Networks named '$($Name)' associated with the Logical Network '$($LogicalNetwork)'."
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set - Create new VM Network fails due to missing Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource when the specified Logical Network does not exist" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose -Debug:$false} | Should Throw "Could not find Logical Network named '$($LogicalNetwork)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network fails due to lack of available SubnetVlans" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @()
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource when VLAN/PVLAN Logical Network does not have any Network Sites defined" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Test-0;10.0.0.0/16-0-0")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The Logical Network specified does not have any available resources to create a subnet for this VM Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network fails due to bad VMSubnets values" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource when VMNetwork string is not properly formatted" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Bad Format")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "VMSubnet value '$($VMSubnets)' is not formatted correctly - should be in the format: 'SubnetName;SubnetIP/Prefix-VlanId-SecondaryVlanId'."
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VMNetwork string is not properly formatted" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Bad Format;1;1-1")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "VMSubnet value '$($VMSubnets)' is not formatted correctly - should be in the format: 'SubnetName;SubnetIP/Prefix-VlanId-SecondaryVlanId'."
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VMNetwork string is not properly formatted" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Bad Format-1-1-1")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "VMSubnet value '$($VMSubnets)' is not formatted correctly - should be in the format: 'SubnetName;SubnetIP/Prefix-VlanId-SecondaryVlanId'."
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VMNetwork string is properly formatted but contains invalid subnet format" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Good Format;1-1-1")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The Subnet '1' contains an invalid IP Address/Prefix value."
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VMNetwork string is properly formatted but contains invalid IP address" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Good Format;1/24-1-1")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The Subnet '1/24' contains an invalid IP Address/Prefix value."
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VMNetwork string is properly formatted but contains invalid network prefix" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Good Format;10.10.0.0/32-0-0")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The Subnet '10.10.0.0/32' contains an invalid IP Address/Prefix value."
            Assert-VerifiableMocks
        }
        It "Set-TargetResource when VMNetwork string is properly formatted but contains invalid VLAN" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @("Good Format;10.10.0.0/24-XX-0")
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The VlanId 'XX' is not a valid value."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network fails due to missing Network Site" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            If ($Name -eq "Missing_Site")
            {
                $returnValue = $null
            }
            Else
            {
                $returnValue = `
                @{
                    Name = $Name
                    SubnetVLans = @($DefaultSubnetVlan)
                }
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource when VLAN/PVLAN Logical Network does not contain the Network Site specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Missing_Site"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Unable to find Network Site named '$($NetworkSite)' on Logical Network '$($LogicalNetwork)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource is successful when PVLAN Logical Network is used" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Description $DefaultDescription -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource is successful when PVLAN Logical Network is used but warns when multiple VMNetworks are specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $VMSubnets = @($DefaultSubnetVlanString,"Extra Subnet;10.10.1.0/24-0-0")
            $NetworkSite = "Test_Site-0"
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource is successful when VLAN Logical Network is used but warns when multiple VMNetworks are specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $VMSubnets = @($DefaultSubnetVlanString,"Extra Subnet;10.10.1.0/24-0-0")
            $NetworkSite = "Test_Site-0"
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource is successful when PVLAN Logical Network is used but warns when IP-based isolation is specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            $Protocol = "IPv4"
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -IsolationVMNetworkProtocol $Protocol -IsolationLogicalNetworkProtocol $Protocol -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource fails when PVLAN Logical Network is used but NetworkSite is not specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $VMSubnets = @($DefaultSubnetVlanString)
            
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "Must specify the Network Site and Subnet/VLAN when creating a VM Network on a PVLAN-based Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource fails when PVLAN Logical Network is used but VMSubnets is not specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $NetworkSite = "Test_Site-0"
            
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Must specify the Network Site and Subnet/VLAN when creating a VM Network on a PVLAN-based Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource is successful when VLAN Logical Network is used but warns when IP-based isolation is specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Test'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            $Protocol = "IPv6"
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -IsolationVMNetworkProtocol $Protocol -IsolationLogicalNetworkProtocol $Protocol -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork New-SCVMNetwork -Verifiable {
            Throw "Error occured during New-SCVMNetwork"
        }
        It "Set-TargetResource fails when VLAN Logical Network is used and New-SCVMNetwork throws and error" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Error occured during New-SCVMNetwork."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork New-SCVMNetwork -Verifiable {
            Throw "Error occured during New-SCVMNetwork"
        }
        It "Set-TargetResource fails when VLAN Logical Network is used and New-SCVMNetwork throws and error" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Error occured during New-SCVMNetwork."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource fails when PVLAN Logical Network is used but logical network does not contain the SubnetVlan specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $SubnetVlan = "192.168.0.0/16-0-0"
            $VMSubnets = @("Test-SubnetVlan;$SubnetVlan")
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Unable to find a Subnet/Vlan matching '$($SubnetVlan)' on the specified Logical Network / Site."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource fails when VLAN Logical Network is used but logical network does not contain the SubnetVlan specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $SubnetVlan = "192.168.0.0/16-0-0"
            $VMSubnets = @("Test-SubnetVlan;$SubnetVlan")
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Unable to find a Subnet/Vlan matching '$($SubnetVlan)' on the specified Logical Network / Site."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to PVLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $true
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            If ($Name -eq "Test_Site-0")
            {
                $returnValue = `
                @{
                    Name = $Name
                    SubnetVLans = @($DefaultSubnetVlan,$UnusedSubnetVlan)
                }
            }
            Else
            {
                $returnValue = `
                @(
                    @{
                        Name = "Test_Site-0"
                        SubnetVLans = @($DefaultSubnetVlan,$UnusedSubnetVlan)
                    },
                    @{
                        Name = "Test_Site-1"
                        SubnetVLans = @(
                            @{
                                Subnet = "10.19.87.0/24"
                                VLanID = 0
                                SecondaryVLanID = 0
                            }
                        )
                    }
                )
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($Name) { return $null }
            $returnValue = `
            @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return $returnValue
        }
        It "Set-TargetResource fails when PVLAN Logical Network is used but the specified SubnetVlan is already assigned to a VM Network" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "The requested Subnet '192.168.0.0/24' is already assigned to a VM Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            If ($Name -eq "Test_Site-0")
            {
                $returnValue = `
                @{
                    Name = $Name
                    SubnetVLans = @($DefaultSubnetVlan,$UnusedSubnetVlan)
                }
            }
            Else
            {
                $returnValue = `
                @(
                    @{
                        Name = "Test_Site-0"
                        SubnetVLans = @($DefaultSubnetVlan,$UnusedSubnetVlan)
                    },
                    @{
                        Name = "Test_Site-1"
                        SubnetVLans = @(
                            @{
                                Subnet = "10.19.87.0/24"
                                VLanID = 0
                                SecondaryVLanID = 0
                            }
                        )
                    }
                )
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($Name) { return $null }
            $returnValue = `
            @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return $returnValue
        }
        It "Set-TargetResource fails when VLAN Logical Network is used but the specified SubnetVlan is already assigned to a VM Network" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "The requested Subnet '192.168.0.0/24' is already assigned to a VM Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource fails when VLAN Logical Network is used with AutoCreateSubnet but there are no available SubnetVlans" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = @($DefaultSubnetVlanString)
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -AutoCreateSubnet $true -Verbose -Debug:$false} | Should Throw "The Logical Network specified does not have any available resources to create a subnet for this VM Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to VLAN type Logical Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        It "Set-TargetResource fails when VLAN Logical Network is used but AutoCreateSubnet or VMSubnets is not specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $NetworkSite = "Test_Site-0"
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite $NetworkSite -Verbose -Debug:$false} | Should Throw "Must specify the Network Site and Subnet/VLAN or use AutoCreateSubnet when creating a VM Network on a VLAN-based Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($Name -eq 'VMNetwork_Fail')
            {
                $returnValue = $null
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    Name = "Existing-VMNetwork"
                    Description = $DefaultDescription
                    IsolationType = "NoIsolation"
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    VMSubnet = @()
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                }
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Set-TargetResource fails when Single Logical Network is used with NoIsolation but another VM Network already exists using NoIsolation" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose -Debug:$false} | Should Throw "There can only be one Non-Isolated VM Network per Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network without Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($Name -eq 'VMNetwork_Fail')
            {
                $returnValue = $null
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    Name = "Existing-VMNetwork"
                    Description = $DefaultDescription
                    IsolationType = "NoIsolation"
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    VMSubnet = @()
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                }
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Set-TargetResource fails when Single Logical Network is used with NoIsolation but another VM Network already exists using NoIsolation" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose -Debug:$false} | Should Throw "There can only be one Non-Isolated VM Network per Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network without Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            $returnValue = `
            @{
                Name = "Existing-VMNetwork"
                IsolationType = "NoIsolation"
                VMSubnet = @()
            }
            return $returnValue
        }
        It "Set-TargetResource fails when protocol-based isolation is specified and a No Isolation VM Network already exists" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -Verbose -Debug:$false} | Should Throw "Network Virtualization is required to create more than one VM Network on this Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network without Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $returnValue = `
                @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource fails when protocol-based isolation is specified when Network Virtualization is not enabled" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -Verbose -Debug:$false} | Should Throw "To use protocol-based isolation for VM Networks, Network Virtualization must be enabled on the Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network without Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $returnValue = `
                @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "VLANNetwork"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource fails when VMSubnets is specified when Network Virtualization is not enabled" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Warn'
            $VMSubnets = $DefaultSubnetVlanString
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "To specify VMSubnets, Network Virtualization must be enabled on the Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network without Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @()
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = ""
                    CAIPAddressPoolType = ""
                    IsolationType = "NoIsolation"
                    #IsolationType =  "WindowsNetworkVirtualization"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource warns when NetworkSite is specified when Network Virtualization is not enabled" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Warn'
            $VMSubnets = $DefaultSubnetVlanString
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite "Ignore_Site" -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = "IPv4"
                    CAIPAddressPoolType = "IPv4"
                    IsolationType =  "WindowsNetworkVirtualization"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource warns when NetworkSite is specified when Network Virtualization is enabled" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Warn'
            $VMSubnets = $DefaultSubnetVlanString
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite "Ignore_Site" -VMSubnets $VMSubnets -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = "IPv4"
                    CAIPAddressPoolType = "IPv4"
                    IsolationType =  "WindowsNetworkVirtualization"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource fails when VMNetworks is specified but IsolationVMNetworkProtocol or IsolationLogicalNetworkProtocol is not specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Warn'
            $VMSubnets = $DefaultSubnetVlanString
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite "Ignore_Site" -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The IsolationVMNetworkProtocol and IsolationLogicalNetworkProtocol paramters must be specified."
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($Name) { return $null }
            $returnValue = `
            @{
                Name = "Existing-VMNetwork"
                IsolationType = "NoIsolation"
                VMSubnet = @()
            }
            return $returnValue
        }
        It "Set-TargetResource fails when IPv4 Logical Network Isolation protocol is specified, but the Logical Nework does not have any IPv4 subnets" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = $DefaultSubnetVlanString
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "Unable to use the specified Isolation Protocol. The Logical Network specified does not contain any IPv4 Subnets."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($Name) { return $null }
            $returnValue = `
            @{
                Name = "Existing-VMNetwork"
                IsolationType = "NoIsolation"
                VMSubnet = @()
            }
            return $returnValue
        }
        It "Set-TargetResource fails when IPv6 Logical Network Isolation protocol is specified, but the Logical Nework does not have any IPv6 subnets" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = $DefaultSubnetVlanString
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv6" -IsolationLogicalNetworkProtocol "IPv6" -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "Unable to use the specified Isolation Protocol. The Logical Network specified does not contain any IPv6 Subnets."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan,$DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            $returnValue = `
            @{
                Name = "Existing-VMNetwork"
                IsolationType = "NoIsolation"
                VMSubnet = @()
            }
            return $returnValue
        }
        It "Set-TargetResource fails when IPv4 VM Network Isolation protocol is specified, but no IPv4 VMSubnets were specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = $DefaultIPv6SubnetVlanString
            $Subnet = ($VMSubnets.Split(';')[1]).Split('-')[0]
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite "Ignore_Site" -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "IPv4 VM Network Isolation was specified, but the VM Network '$($Subnet)' is IPv6."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan,$DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            $returnValue = `
            @{
                Name = "Existing-VMNetwork"
                IsolationType = "NoIsolation"
                VMSubnet = @()
            }
            return $returnValue
        }
        It "Set-TargetResource fails when IPv6 VM Network Isolation protocol is specified, but no IPv6 VMSubnets were specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = $DefaultSubnetVlanString
            $Subnet = ($VMSubnets.Split(';')[1]).Split('-')[0]
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -NetworkSite "Ignore_Site" -IsolationVMNetworkProtocol "IPv6" -IsolationLogicalNetworkProtocol "IPv4" -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "IPv6 VM Network Isolation was specified, but the VM Network '$($Subnet)' is IPv4."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan,$DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = "IPV4"
                    CAIPAddressPoolType = "IPV4"
                    IsolationType =  "WindowsNetworkVirtualization"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultVMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource passes when IPv4 VM Network Isolation protocol is specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Pass'
            $VMSubnets = $DefaultSubnetVlanString
            $Subnet = ($VMSubnets.Split(';')[1]).Split('-')[0]
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -VMSubnets $VMSubnets -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan,$DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -gt 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = "IPV6"
                    CAIPAddressPoolType = "IPV6"
                    IsolationType =  "WindowsNetworkVirtualization"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultIPv6VMSubnet)
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource passes when IPv6 VM Network Isolation protocol is specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Pass'
            $VMSubnets = $DefaultIPv6SubnetVlanString
            $Subnet = ($VMSubnets.Split(';')[1]).Split('-')[0]
            Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv6" -IsolationLogicalNetworkProtocol "IPv6" -VMSubnets $VMSubnets -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan,$DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork New-SCVMNetwork {
            Throw "An error occured in New-SCVMNetwork"
        }
        It "Set-TargetResource fails when New-SCVMNetwork raises an error" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            $VMSubnets = $DefaultSubnetVlanString
            $Subnet = ($VMSubnets.Split(';')[1]).Split('-')[0]
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -IsolationVMNetworkProtocol "IPv4" -IsolationLogicalNetworkProtocol "IPv4" -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "An error occured in New-SCVMNetwork"
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network without Network Virtualization" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetworkDefinition -Verifiable {
            $returnValue = `
            @(
                @{
                    Name = "Test_Site-0"
                    SubnetVLans = @($DefaultIPv6SubnetVlan,$DefaultSubnetVlan)
                }
            )
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            return $null
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork New-SCVMNetwork {
            Throw "An error occured in New-SCVMNetwork"
        }
        It "Set-TargetResource fails when New-SCVMNetwork raises an error" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fail'
            {Set-TargetResource -Name $Name -LogicalNetwork $LogicalNetwork -Verbose -Debug:$false} | Should Throw "An error occured in New-SCVMNetwork"
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Create new VM Network associated to Single type Logical Network with Network Virtualization enabled" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $true
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -lt 1)
            {
                return $null
            }
        }
        It "Set-TargetResource fails when VMSubnets is specified but Isolation protocol is not specified" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Fails'
            $VMSubnets = $DefaultSubnetVlanString
            {Set-TargetResource -Ensure "Present" -Name $Name -LogicalNetwork $LogicalNetwork -VMSubnets $VMSubnets -Verbose -Debug:$false} | Should Throw "The IsolationVMNetworkProtocol and IsolationLogicalNetworkProtocol paramters must be specified."
            Assert-VerifiableMocks
        }
    }
    
    Context "Test/Set - Remove VM Network" {
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCLogicalNetwork -Verifiable {
            $returnValue = `
            @{
                Name = $Name
                IsLogicalNetworkDefinitionIsolated = $false
                NetworkVirtualizationEnabled = $false
                IsPVLAN = $false
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMVMNetwork Get-SCVMNetwork -Verifiable {
            If ($global:FunctionCounter -lt 1)
            {
                $returnValue = `
                @{
                    Name = $Name
                    Description = $DefaultDescription
                    PAIPAddressPoolType = "IPV6"
                    CAIPAddressPoolType = "IPV6"
                    IsolationType =  "WindowsNetworkVirtualization"
                    LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                    VMSubnet = @($DefaultIPv6VMSubnet)
                }
            }
            Else
            {
                $returnValue =  $null
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource removes a VM Network" {
            $LogicalNetwork = $DefaultLogicalNetworkName
            $Name = 'VMNetwork_Remove'
            Set-TargetResource -Ensure "Absent" -Name $Name -LogicalNetwork $LogicalNetwork -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
}

Get-Module -Name VirtualMachineManager | Remove-Module
