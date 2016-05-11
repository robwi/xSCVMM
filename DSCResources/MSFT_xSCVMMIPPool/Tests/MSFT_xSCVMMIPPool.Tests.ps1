<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMIPPool.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCVMMIPPool.psm1"
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
    function Set-SCStaticIPAddressPool
    {
    }
    function New-SCStaticIPAddressPool
    {
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
            [System.String]$Subnet,
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
            $LogicalNetworkDefinition,
            $VMSubnet,
            $Subnet
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
            $VMNetwork,
            $Subnet
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
    function New-SCDefaultGateway
    {
        param
        (
            [System.String]$IPAddress,
            [Int32]$Metric,
            [Switch]$Automatic
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

Describe "MSFT_xSCVMMIPPool Tests" {

    $global:FunctionCounter = 0
    $global:DefaultLogicalNetworkName = "LN_Test"
    $global:DefaultLogicalNetworkDef = "LND_Test"
    $global:DefaultVMNetworkName = "VMNetwork_Test"
    $global:DefaultDescription = "Test Description"
    
    $global:DefaultIPStart = '10.10.10.1'
    $global:DefaultIPEnd = '10.10.10.254'
    $global:DefaultGateway = New-Object PSObject -Property @{
        IPAddress = $global:DefaultIPStart 
        Metric = ""
    }
    $global:DefaultDNS = @('10.10.10.2','10.10.10.3')
    $global:DefaultWINS = @('10.10.10.4','10.10.10.5')
    $global:DefaultSubnet = '10.10.10.0/24'
    $global:DefaultSubnetVlan = `
    @{
        Subnet = $DefaultSubnet
        VLanID = 0
        SecondaryVLanID = 0
    }
    $global:DefaultSubnetVlanString = "Test-SubnetVlan;$DefaultSubnet-0-0"
    
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
        VLanID = 0
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
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            If ($Name)
            {
                $returnValue = @($Item)
            }
            Else
            {
                $returnValue = @($Item,@{Name = "Xtra_Network";VMSubnet = @($UnusedSubnetVlan)})
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            return "Some_VMSubnet"
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                IPAddressRangeStart = $DefaultIPStart
                IPAddressRangeEnd = $DefaultIPEnd
                DefaultGateways = @($DefaultGateway)
                DNSServers = $DefaultDNS
                DNSSearchSuffixes = @()
                WINSServers = $DefaultWINS
                EnableNetBIOS = $false
                VIPAddressSet = @()
                IPAddressReservedSet = @()
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource succeeds when a VMNetwork is specified" {
            $Name = 'IPPool_Present'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.IPAddressRange | Should Match ($DefaultIPStart + "-" + $DefaultIPEnd)
            $result.Gateway | Should Match '10.10.10.1'
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            If ($Name)
            {
                $returnValue = @($Item)
            }
            Else
            {
                $returnValue = @($Item,@{Name = "Xtra_Network";VMSubnet = @($UnusedSubnetVlan)})
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            return "Some_VMSubnet"
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                IPAddressRangeStart = $DefaultIPStart
                IPAddressRangeEnd = $DefaultIPEnd
                DefaultGateways = @($DefaultGateway)
                DNSServers = $DefaultDNS
                DNSSearchSuffixes = @()
                WINSServers = $DefaultWINS
                EnableNetBIOS = $false
                VIPAddressSet = @()
                IPAddressReservedSet = @()
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource succeeds when a VMNetwork and Subnet is specified" {
            $Name = 'IPPool_Present'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $SourceNetworkSubnet = $DefaultSubnet
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.IPAddressRange | Should Match ($DefaultIPStart + "-" + $DefaultIPEnd)
            $result.Gateway | Should Match '10.10.10.1'
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                IPAddressRangeStart = $DefaultIPStart
                IPAddressRangeEnd = $DefaultIPEnd
                DefaultGateways = @($DefaultGateway)
                DNSServers = $DefaultDNS
                DNSSearchSuffixes = @()
                WINSServers = $DefaultWINS
                EnableNetBIOS = $false
                VIPAddressSet = @()
                IPAddressReservedSet = @()
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource succeeds when a Logical Network is specified" {
            $Name = 'IPPool_Present'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.IPAddressRange | Should Match ($DefaultIPStart + "-" + $DefaultIPEnd)
            $result.Gateway | Should Match '10.10.10.1'
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                IPAddressRangeStart = $DefaultIPStart
                IPAddressRangeEnd = $DefaultIPEnd
                DefaultGateways = @($DefaultGateway)
                DNSServers = $DefaultDNS
                DNSSearchSuffixes = @()
                WINSServers = $DefaultWINS
                EnableNetBIOS = $false
                VIPAddressSet = @()
                IPAddressReservedSet = @()
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource succeeds when a Logical Network and Network Site is specified" {
            $Name = 'IPPool_Present'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $SourceNetworkSite = $DefaultLogicalNetworkDef
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSite $SourceNetworkSite -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.IPAddressRange | Should Match ($DefaultIPStart + "-" + $DefaultIPEnd)
            $result.Gateway | Should Match '10.10.10.1'
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                IPAddressRangeStart = $DefaultIPStart
                IPAddressRangeEnd = $DefaultIPEnd
                DefaultGateways = @($DefaultGateway)
                DNSServers = $DefaultDNS
                DNSSearchSuffixes = @()
                WINSServers = $DefaultWINS
                EnableNetBIOS = $false
                VIPAddressSet = @()
                IPAddressReservedSet = @()
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource succeeds when a Logical Network, Network Site and Subnet is specified" {
            $Name = 'IPPool_Present'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $SourceNetworkSite = $DefaultLogicalNetworkDef
            $SourceNetworkSubnet = $DefaultSubnet
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSite $SourceNetworkSite -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.IPAddressRange | Should Match ($DefaultIPStart + "-" + $DefaultIPEnd)
            $result.Gateway | Should Match '10.10.10.1'
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Present" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                Description = $DefaultDescription
                IPAddressRangeStart = $DefaultIPStart
                IPAddressRangeEnd = $DefaultIPEnd
                DefaultGateways = @($DefaultGateway)
                DNSServers = $DefaultDNS
                DNSSearchSuffixes = @()
                WINSServers = $DefaultWINS
                EnableNetBIOS = $false
                VIPAddressSet = @()
                IPAddressReservedSet = @()
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource succeeds when a Logical Network and Subnet is specified" {
            $Name = 'IPPool_Absent'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $SourceNetworkSubnet = $DefaultSubnet
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false
            $result.Ensure | Should Be "Present"
            $result.Name | Should Be $Name
            $result.IPAddressRange | Should Match ($DefaultIPStart + "-" + $DefaultIPEnd)
            $result.Gateway | Should Match '10.10.10.1'
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Absent" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            If ($Name)
            {
                $returnValue = @($Item)
            }
            Else
            {
                $returnValue = @($Item,@{Name = "Xtra_Network";VMSubnet = @($UnusedSubnetVlan)})
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            return "Some_VMSubnet"
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Get-TargetResource when VM Network is specified but no IP Pools exist" {
            $Name = 'IPPool_Absent'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false
            $result.Ensure | Should Be "Absent"
            $result.Description | Should BeNullOrEmpty
            $result.IPAddressRange | Should BeNullOrEmpty
            $result.Gateway | Should BeNullOrEmpty
            $result.DnsServer | Should BeNullOrEmpty
            $result.DnsSuffix | Should BeNullOrEmpty
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Absent" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Get-TargetResource when Logical Network is specified but no IP Pools exist" {
            $Name = 'IPPool_Absent'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $result = Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false
            $result.Ensure | Should Be "Absent"
            $result.Description | Should BeNullOrEmpty
            $result.IPAddressRange | Should BeNullOrEmpty
            $result.Gateway | Should BeNullOrEmpty
            $result.DnsServer | Should BeNullOrEmpty
            $result.DnsSuffix | Should BeNullOrEmpty
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
        }
        It "Get-TargetResource fails when the VM Network is specified does not exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false} | Should Throw "The VM Network '$($SourceNetworkName)' could not be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            If ($Name)
            {
                $returnValue = @($Item)
            }
            Else
            {
                $returnValue = @($Item,@{Name = "Xtra_Network";VMSubnet = @($UnusedSubnetVlan)})
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
        }
        It "Get-TargetResource fails when the VM Network and Subnet is specified but the Subnet does not exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $SourceNetworkSubnet = $DefaultSubnet
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false} | Should Throw "Subnet on the VM Network '$($SourceNetworkName)' could not be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @()
            }
            If ($Name)
            {
                $returnValue = @($Item)
            }
            Else
            {
                $returnValue = @($Item,@{Name = "Xtra_Network";VMSubnet = @($UnusedSubnetVlan)})
            }
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
        }
        It "Get-TargetResource fails when the VM Network is found but no Subnets exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $SourceNetworkSubnet = $DefaultSubnet
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false} | Should Throw "Subnet on the VM Network '$($SourceNetworkName)' could not be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @()
                IsolationType = "VLANNetwork"
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource fails when the VM Network is based on a Logical Network using VLAN Isolation" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $SourceNetworkSubnet = $DefaultSubnet
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false} | Should Throw "For networks using VLAN-based isolation you must create the Static IP Pool on the Logical Network."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @()
                IsolationType = "NoIsolation"
            }
            $returnValue = @($Item)
            return $returnValue
        }
        It "Get-TargetResource fails when No Isolation is used" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $SourceNetworkSubnet = $DefaultSubnet
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSubnet $SourceNetworkSubnet -Verbose -Debug:$false} | Should Throw "Cannot create a Static IP Address Pool on a VM Network using No Isolation."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
        }
        It "Get-TargetResource fails when the Logical Network is specified does not exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false} | Should Throw "The Logical Network '$($SourceNetworkName)' could not be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            If (-not $Name)
            {
               return @(@{Name = "SomeNetwork_Site"})
            }
        }
        It "Get-TargetResource fails when the Logical Network and Network Site is specified but the Network Site does not exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $SourceNetworkSite = $DefaultLogicalNetworkDef
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSite $SourceNetworkSite -Verbose -Debug:$false} | Should Throw "The specified Network Site '$($SourceNetworkSite)' could not be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Get Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
        }
        It "Get-TargetResource fails when the Logical Network exists but no Network Sites exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $SourceNetworkSite = $DefaultLogicalNetworkDef
            {Get-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -SourceNetworkSite $SourceNetworkSite -Verbose -Debug:$false} | Should Throw "The Logical Network '$($SourceNetworkName)' does not contain any Network Sites."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
        }
        It "Set-TargetResource fails when the VM Network exists but no Subnets exist" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Verbose -Debug:$false} | Should Throw "Subnet on the VM Network '$($SourceNetworkName)' could not be found."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource fails when the IPAddressRange string is not properly formatted" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $IPAddressRange = "192.168.0.1;192.168.0.254"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Verbose -Debug:$false} | Should Throw "IPAddressRange string is not in the proper format. Should be: 'StartIP-EndIP'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource fails when the IPAddressRange Start address is invalid" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $IPAddressRange = "BAD_ADDRESS-192.168.0.254"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Verbose -Debug:$false} | Should Throw "IPAddressRange start address 'BAD_ADDRESS' is invalid."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource fails when the IPAddressRange End address is invalid" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $IPAddressRange = "192.168.0.1-BAD_ADDRESS"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Verbose -Debug:$false} | Should Throw "IPAddressRange end address 'BAD_ADDRESS' is invalid."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource fails when the IPAddressRange Start address is not in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $BegIP = "10.10.12.1"
            $EndIP = "10.10.10.254"
            $IPAddressRange = "$BegIP-$EndIP"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Verbose -Debug:$false} | Should Throw "The start address '$($BegIP)' is not in the subnet '$($Subnet)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource fails when the IPAddressRange End address is not in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $BegIP = "10.10.10.1"
            $EndIP = "10.10.12.254"
            $IPAddressRange = "$BegIP-$EndIP"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Verbose -Debug:$false} | Should Throw "The end address '$($EndIP)' is not in the subnet '$($Subnet)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when an invalid Gateway address is specified" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $BegIP = "10.10.10.1"
            $EndIP = "10.10.10.200"
            $IPAddressRange = "$BegIP-$EndIP"
            $Address = "10.10.257.1"
            $Gateway = @($Address)
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -Verbose -Debug:$false} | Should Throw "Gateway address '$($Address)' is invalid."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when an invalid Gateway metric is specified" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $Address = "10.10.10.1"
            $Metric = "XX"
            $Gateway = @("$Address;$Metric")
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -Gateway $Gateway -Verbose -Debug:$false} | Should Throw "Gateway metric must be a number between 1 and 9999."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when Gateway address is not in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $Subnet = $DefaultSubnet
            $BegIP = "10.10.10.1"
            $EndIP = "10.10.10.200"
            $IPAddressRange = "$BegIP-$EndIP"
            $Address = "10.10.12.1"
            $Metric = "100"
            $Gateway = @("$Address;$Metric")
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -Verbose -Debug:$false} | Should Throw "The gateway address '$($Address)' is not in the subnet '$($Subnet)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when DNS address is not a valid IP address" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $BegIP = "10.10.10.2"
            $EndIP = "10.10.10.200"
            $IPAddressRange = "$BegIP-$EndIP"
            $Address = "10.10.10.1"
            $Metric = "100"
            $DnsServer = @("8.8.8.8","8.8.8.X")
            $Gateway = @("$Address;$Metric")
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -DnsServer $DnsServer -Gateway $Gateway -Verbose -Debug:$false} | Should Throw "The DNS Server address '8.8.8.X' is not a valid IP address."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when WINS address is not a valid IP address" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $BegIP = "10.10.10.2"
            $EndIP = "10.10.10.200"
            $IPAddressRange = "$BegIP-$EndIP"
            $Address = "10.10.10.1"
            $Metric = "100"
            $DnsServer = @("8.8.8.8")
            $WinsServer = @("7.7.7.7","7.7.777")
            $Gateway = @("$Address;$Metric")
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -WinsServer $WinsServer -DnsServer $DnsServer -Gateway $Gateway -Verbose -Debug:$false} | Should Throw "The WINS Server address '7.7.777' is not a valid IP address."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when VIP start address is not in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $IPAddressRange = "10.10.10.2-10.10.10.254"
            $BegVIP = "10.10.12.140"
            $EndVIP = "10.10.10.159"
            $VIPReservation = "10.10.10.99,$BegVIP-$EndVIP"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -VIPReservation $VIPReservation -Verbose -Debug:$false} | Should Throw "VIP range start address '$($BegVIP)' is not in the subnet '$($Subnet)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when VIP end address is not in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $IPAddressRange = "10.10.10.2-10.10.10.254"
            $BegVIP = "10.10.10.140"
            $EndVIP = "10.10.12.159"
            $VIPReservation = "10.10.10.99,$BegVIP-$EndVIP"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -VIPReservation $VIPReservation -Verbose -Debug:$false} | Should Throw "VIP range end address '$($EndVIP)' is not in the subnet '$($Subnet)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
        }
        It "Set-TargetResource when VIP address is not in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $Subnet = $DefaultSubnet
            $IPAddressRange = "10.10.10.2-10.10.10.254"
            $BegVIP = "10.10.10.140"
            $EndVIP = "10.10.10.159"
            $BadVIP = "10.10.12.99"
            $VIPReservation = "$BadVIP,$BegVIP-$EndVIP"
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -VIPReservation $VIPReservation -Verbose -Debug:$false} | Should Throw "VIP address '$($BadVIP)' is not in the subnet '$($Subnet)'."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set Fails" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $returnValue = @()
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    IPAddressRangeStart = $DefaultIPStart
                    IPAddressRangeEnd = $DefaultIPEnd
                    DefaultGateways = @($DefaultGateway)
                    DNSServers = $DefaultDNS
                    DnsSuffix = "contoso.com"
                    DNSSearchSuffixes = @("northwind.com","fabrikam.com")
                    WINSServers = $DefaultWINS
                    EnableNetBIOS = $true
                    VIPAddressSet = @("10.10.10.140-10.10.10.159")
                    IPAddressReservedSet = @("10.10.10.179","10.10.10.199")
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource fails when using a VM Network and the start range is using the first address in the subnet" {
            $Name = 'IPPool_Fails'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $IPAddressRange = "$DefaultIPStart-$DefaultIPEnd"
            $DnsServer = $DefaultDNS
            $DnsSuffix = "contoso.com"
            $DnsSearchSuffix = @("northwind.com","fabrikam.com")
            $WinsServer = $DefaultWINS
            $NetBIOSOverTCPIP = $true
            $Gateway = @($DefaultIPStart)
            $VIPReservation = @("10.10.10.140-10.10.10.159")
            $OtherReservation = @("10.10.10.179","10.10.10.199")
            {Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -DnsServer $DnsServer -DnsSearchSuffix $DnsSearchSuffix -DnsSuffix $DnsSuffix -NetBIOSOverTCPIP $NetBIOSOverTCPIP -WinsServer $WinsServer -VIPReservation $VIPReservation -OtherReservation $OtherReservation -Verbose -Debug:$false} | Should Throw "The first address of a subnet on a VM Network using Network Virtualization is reserved for the gateway."
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $returnValue = @()
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    IPAddressRangeStart = '10.10.10.2'
                    IPAddressRangeEnd = $DefaultIPEnd
                    DefaultGateways = @($DefaultGateway)
                    DNSServers = $DefaultDNS
                    DnsSuffix = "contoso.com"
                    DNSSearchSuffixes = @("northwind.com","fabrikam.com")
                    WINSServers = $DefaultWINS
                    EnableNetBIOS = $true
                    VIPAddressSet = @("10.10.10.140-10.10.10.159")
                    IPAddressReservedSet = @("10.10.10.179","10.10.10.199")
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource succeeds when using a VM Network" {
            $Name = 'IPPool_Passes'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $IPAddressRange = "10.10.10.2-$DefaultIPEnd"
            $DnsServer = $DefaultDNS
            $DnsSuffix = "contoso.com"
            $DnsSearchSuffix = @("northwind.com","fabrikam.com")
            $WinsServer = $DefaultWINS
            $NetBIOSOverTCPIP = $true
            $Gateway = @($DefaultIPStart)
            $VIPReservation = @("10.10.10.140-10.10.10.159")
            $OtherReservation = @("10.10.10.179","10.10.10.199")
            $result = Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -DnsServer $DnsServer -DnsSearchSuffix $DnsSearchSuffix -DnsSuffix $DnsSuffix -NetBIOSOverTCPIP $NetBIOSOverTCPIP -WinsServer $WinsServer -VIPReservation $VIPReservation -OtherReservation $OtherReservation -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
                LogicalNetwork = @{Name = $DefaultLogicalNetworkName}
                VMSubnet = @($DefaultVMSubnet)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCVMSubnet -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = "Some_Subnet"
                SubnetVLans = @($DefaultSubnetVlan)
            }
            return @($Item)
        }
        Mock -ModuleName MSFT_xSCVMMIPPool New-SCDefaultGateway -Verifiable {
            $Item = New-Object PSObject -Property @{
                $IPAddress = $IPAddress
                $Metric = $Metric
            }
            return $Item
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    IPAddressRangeStart = '10.10.10.2'
                    IPAddressRangeEnd = $DefaultIPEnd
                    Subnet = $DefaultSubnet
                    DefaultGateways = @($DefaultGateway)
                    DNSServers = $DefaultDNS
                    DnsSuffix = "contoso.com"
                    DNSSearchSuffixes = @("northwind.com","fabrikam.com")
                    WINSServers = $DefaultWINS
                    EnableNetBIOS = $true
                    VIPAddressSet = @("10.10.10.140-10.10.10.159")
                    IPAddressReservedSet = @("10.10.10.179","10.10.10.199")
                }
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = "This should change"
                    IPAddressRangeStart = '10.10.10.2'
                    IPAddressRangeEnd = $DefaultIPEnd
                    Subnet = $DefaultSubnet
                    DefaultGateways = @()
                    DNSServers = @()
                    DnsSuffix = ""
                    DNSSearchSuffixes = @()
                    WINSServers = @()
                    EnableNetBIOS = $false
                    VIPAddressSet = @()
                    IPAddressReservedSet = @()
                }
            }
            $returnValue = @($Item)
            $global:FunctionCounter++
            return $returnValue
        }
        It "Set-TargetResource succeeds when using a VM Network and the IP Pool already exists" {
            $Name = 'IPPool_Passes'
            $SourceNetworkName = $DefaultVMNetworkName
            $SourceNetworkType = "VMNetwork"
            $IPAddressRange = "10.10.10.2-$DefaultIPEnd"
            $DnsServer = $DefaultDNS
            $DnsSuffix = "contoso.com"
            $DnsSearchSuffix = @("northwind.com","fabrikam.com")
            $WinsServer = $DefaultWINS
            $NetBIOSOverTCPIP = $true
            $Gateway = @($DefaultIPStart)
            $VIPReservation = @("10.10.10.140-10.10.10.159")
            $OtherReservation = @("10.10.10.179","10.10.10.199")
            $result = Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -DnsServer $DnsServer -DnsSearchSuffix $DnsSearchSuffix -DnsSuffix $DnsSuffix -NetBIOSOverTCPIP $NetBIOSOverTCPIP -WinsServer $WinsServer -VIPReservation $VIPReservation -OtherReservation $OtherReservation -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $returnValue = @()
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    IPAddressRangeStart = $DefaultIPStart
                    IPAddressRangeEnd = $DefaultIPEnd
                    DefaultGateways = @($DefaultGateway)
                    DNSServers = $DefaultDNS
                    DnsSuffix = "contoso.com"
                    DNSSearchSuffixes = @("northwind.com","fabrikam.com")
                    WINSServers = $DefaultWINS
                    EnableNetBIOS = $true
                    VIPAddressSet = @("10.10.10.140-10.10.10.159")
                    IPAddressReservedSet = @("10.10.10.179","10.10.10.199")
                }
                $returnValue = @($Item)
            }
            $global:FunctionCounter++
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool New-SCDefaultGateway -Verifiable {
            $Item = New-Object PSObject -Property @{
                $IPAddress = $IPAddress
                $Metric = $Metric
            }
            return $Item
        }
        It "Set-TargetResource succeeds when using a Logical Network" {
            $Name = 'IPPool_Passes'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $IPAddressRange = "$DefaultIPStart-$DefaultIPEnd"
            $DnsServer = $DefaultDNS
            $DnsSuffix = "contoso.com"
            $DnsSearchSuffix = @("northwind.com","fabrikam.com")
            $WinsServer = $DefaultWINS
            $NetBIOSOverTCPIP = $true
            $Gateway = @($DefaultIPStart)
            $VIPReservation = @("10.10.10.140-10.10.10.159")
            $OtherReservation = @("10.10.10.179","10.10.10.199")
            $result = Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -DnsServer $DnsServer -DnsSearchSuffix $DnsSearchSuffix -DnsSuffix $DnsSuffix -NetBIOSOverTCPIP $NetBIOSOverTCPIP -WinsServer $WinsServer -VIPReservation $VIPReservation -OtherReservation $OtherReservation -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
    Context "Set/Test Succeeds" {
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetwork -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $Name
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCLogicalNetworkDefinition -Verifiable {
            $Item = New-Object PSObject -Property @{
                Name = $DefaultLogicalNetworkDef
                HostGroups = @(
                    @{
                        Name = "All Hosts"
                    }
                )
                SubnetVLans = @($DefaultSubnetVlan)
            }
            $returnValue = @($Item)
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool Get-SCStaticIPAddressPool -Verifiable {
            $returnValue = @()
            If ($global:FunctionCounter -ge 1)
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = $DefaultDescription
                    IPAddressRangeStart = $DefaultIPStart
                    IPAddressRangeEnd = $DefaultIPEnd
                    Subnet = $DefaultSubnet
                    DefaultGateways = @($DefaultGateway)
                    DNSServers = $DefaultDNS
                    DnsSuffix = "contoso.com"
                    DNSSearchSuffixes = @("northwind.com","fabrikam.com")
                    WINSServers = $DefaultWINS
                    EnableNetBIOS = $true
                    VIPAddressSet = @("10.10.10.140-10.10.10.159")
                    IPAddressReservedSet = @("10.10.10.179","10.10.10.199")
                }
            }
            Else
            {
                $Item = New-Object PSObject -Property @{
                    Name = $Name
                    Description = "This should change"
                    IPAddressRangeStart = $DefaultIPStart
                    IPAddressRangeEnd = $DefaultIPEnd
                    Subnet = $DefaultSubnet
                    DefaultGateways = @()
                    DNSServers = @()
                    DnsSuffix = ""
                    DNSSearchSuffixes = @()
                    WINSServers = @()
                    EnableNetBIOS = $false
                    VIPAddressSet = @()
                    IPAddressReservedSet = @()
                }
            }
            $returnValue = @($Item)
            $global:FunctionCounter++
            return $returnValue
        }
        Mock -ModuleName MSFT_xSCVMMIPPool New-SCDefaultGateway -Verifiable {
            $Item = New-Object PSObject -Property @{
                $IPAddress = $IPAddress
                $Metric = $Metric
            }
            return $Item
        }
        It "Set-TargetResource succeeds when using a Logical Network and the IP Pool already exists" {
            $Name = 'IPPool_Passes'
            $SourceNetworkName = $DefaultLogicalNetworkName
            $SourceNetworkType = "LogicalNetwork"
            $IPAddressRange = "$DefaultIPStart-$DefaultIPEnd"
            $DnsServer = $DefaultDNS
            $DnsSuffix = "contoso.com"
            $DnsSearchSuffix = @("northwind.com","fabrikam.com")
            $WinsServer = $DefaultWINS
            $NetBIOSOverTCPIP = $true
            $Gateway = @($DefaultIPStart)
            $VIPReservation = @("10.10.10.140-10.10.10.159")
            $OtherReservation = @("10.10.10.179","10.10.10.199")
            $result = Set-TargetResource -Name $Name -SourceNetworkName $SourceNetworkName -SourceNetworkType $SourceNetworkType -IPAddressRange $IPAddressRange -Gateway $Gateway -DnsServer $DnsServer -DnsSearchSuffix $DnsSearchSuffix -DnsSuffix $DnsSuffix -NetBIOSOverTCPIP $NetBIOSOverTCPIP -WinsServer $WinsServer -VIPReservation $VIPReservation -OtherReservation $OtherReservation -Verbose -Debug:$false
            Assert-VerifiableMocks
        }
    }
    
}

Get-Module -Name VirtualMachineManager | Remove-Module
