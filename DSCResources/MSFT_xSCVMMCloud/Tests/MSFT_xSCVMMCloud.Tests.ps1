<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMCloud.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

#region Shell Modules

# Create Empty Mockable Modules that dont exist on a default windows install
Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    function Get-SCVMHostGroup 
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCCloud
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function New-SCCloud
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMHostGroup,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Set-SCCloud
    {
        [CmdletBinding()]
        param
        (
            $Cloud,
            $Description,
            $AddVMHostGroup,
            $AddReadOnlyLibraryShare,
            $AddCloudResource,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Set-SCCloudCapacity
    {
        [CmdletBinding()]
        param
        (
            $CloudCapacity,
            $UseCustomQuotaCountMaximum,
            $UseMemoryMBMaximum,
            $UseCPUCountMaximum,
            $UseStorageGBMaximum,
            $UseVMCountMaximum,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCLibraryShare
    {
        [CmdletBinding()]
        param
        (
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Remove-SCCloud
    {
        [CmdletBinding()]
        param
        (
            $Cloud,
            $ErrorActionPreference
        )
    }

    function Get-SCVMMServer
    {
        [CmdletBinding()]
        param
        (
            $ComputerName,
            $ErrorActionPreference
        )

        'VMMServerConnection'
    }

    function Get-SCLogicalNetwork 
    {
        [CmdletBinding()]
        param
        (
            [Switch]$All,
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCLoadBalancer
    {
        [CmdletBinding()]
        param
        (
            [Switch]$All,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCPortClassification
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCStorageClassification
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force

#endregion

#region Load Test Files
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$testModule = "$here\..\MSFT_xSCVMMCloud.psm1"

If (Test-Path $testModule)
{
    Import-Module $testModule -Force -ErrorAction Stop
}
Else
{
    Throw "Unable to find '$testModule'"
}
#endregion

InModuleScope MSFT_xSCVMMCloud {

    #region Mock Variables

    # Input Mocks
    $mockCloudName = "Mock Cloud"
    $mockDescription = "Mock Description"

    $mockHostGroupName1 = "Mock Group 1"
    $mockHostGroupName2 = "Mock Group 2"
    $mockHostGroupName3 = "Mock Group 3"
    $mockHostGroupNames = @($mockHostGroupName1, $mockHostGroupName2)

    $mockReadLibraryShareName1 = "Mock Share 1"
    $mockReadLibraryShareName2= "Mock Share 2"
    $mockReadLibraryShareName3= "Mock Share 3"
    $mockReadLibraryShareNames = @($mockReadLibraryShareName1, $mockReadLibraryShareName2)

    $mockPortClassificationName1 = "Mock Port Classification 1"
    $mockPortClassificationName2 = "Mock Port Classification 2"
    $mockPortClassificationName3 = "Mock Port Classification 3"
    $mockPortClassificationNames = @($mockPortClassificationName1, $mockPortClassificationName2)

    $mockStorageClassificationName1 = "Mock Storage Classification 1"
    $mockStorageClassificationName2 = "Mock Storage Classification 2"
    $mockStorageClassificationName3 = "Mock Storage Classification 3"
    $mockStorageClassificationNames = @($mockStorageClassificationName1, $mockStorageClassificationName2)

    $mockLogicalNetworkName1 = "Mock Logical Network 1"
    $mockLogicalNetworkName2= "Mock Logical Network 2"
    $mockLogicalNetworkName3= "Mock Logical Network 3"
    $mockLogicalNetworkNames = @($mockLogicalNetworkName1, $mockLogicalNetworkName2)

    $mockLoadBalancerName1 = "Mock Load Balancer Name 1"
    $mockLoadBalancerName2 = "Mock Load Balancer Name 2"
    $mockLoadBalancerName3 = "Mock Load Balancer Name 3"
    $mockLoadBalancerNames = @($mockLoadBalancerName1, $mockLoadBalancerName2)

    # Mock Returns
    $mockHostGroup1 = @{ Name = $mockHostGroupName1; ObjectType = '' }
    $mockHostGroup2 = @{ Name = $mockHostGroupName2; ObjectType = '' }
    $mockHostGroup3 = @{ Name = $mockHostGroupName3; ObjectType = '' }

    $mockLibraryShare1 = @{ Name = $mockReadLibraryShareName1}
    $mockLibraryShare2 = @{ Name = $mockReadLibraryShareName2}
    $mockLibraryShare3 = @{ Name = $mockReadLibraryShareName3}

    $mockPortClassification1 = @{ Name = $mockPortClassificationName1; ObjectType = 'PortClassification' }
    $mockPortClassification2 = @{ Name = $mockPortClassificationName2; ObjectType = 'PortClassification' }
    $mockPortClassification3 = @{ Name = $mockPortClassificationName3; ObjectType = 'PortClassification' }

    $mockStorageClassification1 = @{ Name = $mockStorageClassificationName1; ObjectType = 'StorageClassification' }
    $mockStorageClassification2 = @{ Name = $mockStorageClassificationName2; ObjectType = 'StorageClassification' }
    $mockStorageClassification3 = @{ Name = $mockStorageClassificationName3; ObjectType = 'StorageClassification' }

    $mockLoadBalancer1 = @{ Name = $mockLoadBalancerName1; ObjectType = 'LoadBalancer' }
    $mockLoadBalancer2 = @{ Name = $mockLoadBalancerName2; ObjectType = 'LoadBalancer' }
    $mockLoadBalancer3 = @{ Name = $mockLoadBalancerName3; ObjectType = 'LoadBalancer' }

    $mockLogicalNetwork1 = @{ Name = $mockLogicalNetworkName1; ObjectType = 'LogicalNetwork' }
    $mockLogicalNetwork2 = @{ Name = $mockLogicalNetworkName2; ObjectType = 'LogicalNetwork' }
    $mockLogicalNetwork3 = @{ Name = $mockLogicalNetworkName3; ObjectType = 'LogicalNetwork' }

    #endregion

    Describe "MSFT_xSCVMMCloud Tests" {

        #region Describe Mocks
        Mock -ModuleName SCVMMHelper  -CommandName Get-SCVMMServer -Verifiable {

            Write-Verbose "Mock Get-SCVMMServer $args"

            "LibraryServer"
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCCloud  {

            Write-Verbose "Mock Get-SCCloud $args"

            @{ Name = $mockCloudName
                Description = $mockDescription
                HostGroup = @($mockHostGroup1 ,$mockHostGroup2)
                ReadableLibraryPaths = @($mockLibraryShare1, $mockLibraryShare2)
                LogicalNetworks = @($mockLogicalNetwork1,$mockLogicalNetwork2)
                LoadBalancers = @($mockLoadBalancer1, $mockLoadBalancer2)
                StorageClassifications = @($mockStorageClassification1, $mockStorageClassification2)
                PortClassifications = @($mockPortClassification1,$mockPortClassification2)
            }
                                            
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCVMHostGroup  {

            Write-Verbose "Mock Get-SCVMHostGroup $args"
            
            # Return back the HostGroup Name provided
            @{ Name = $Name }
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCLibraryShare  {

            Write-Verbose "Mock Get-SCLibraryShare $args"

            $mockLibraryShare1
            $mockLibraryShare2
            $mockLibraryShare3
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCLogicalNetwork   {

            Write-Verbose "Mock Get-SCLogicalNetwork $args"

            @{ Name = $Name; ObjectType = 'LogicalNetwork' }
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCLoadBalancer {

            Write-Verbose "Mock Get-SCLoadBalancer $args"

            $mockLoadBalancer1
            $mockLoadBalancer2
            $mockLoadBalancer3 
        } 

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCPortClassification  {

            Write-Verbose "Mock Get-SCPortClassification $args"

            @{ Name = $Name; ObjectType = 'PortClassification' }
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCStorageClassification  {

            Write-Verbose "Mock Get-SCStorageClassification $args"

            @{ Name = $Name; ObjectType = 'StorageClassification' }
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName New-SCCloud  {

            Write-Verbose "Mock New-SCCloud $args"
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Set-SCCloud  {

            Write-Verbose "Mock Set-SCCloud $args"
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Remove-SCCloud  {

            Write-Verbose "Mock Remove-SCCloud $args"
        }

        Mock -ModuleName MSFT_xSCVMMCloud -CommandName Set-SCCloudCapacity  {

            Write-Verbose "Mock Set-SCCloudCapacity $args"
        }

        #endregion

        Context "No Context Mocks" {

            It "Get-TargetResource Present" {
                
                $result = Get-TargetResource -Name $mockCloudName -Verbose

                $result.Ensure | Should be "Present"
                $result.Name | Should be $mockCloudName
                $result.Description | Should be $mockDescription
                $result.HostGroupNames.Count | Should be 2
                $result.ReadLibraryShareNames.Count | Should be 2 
                $result.LogicalNetworkNames.Count | Should be 2 
                $result.LoadBalancerNames.Count | Should be 2 
                $result.PortClassificationNames.Count | Should be 2 
                $result.StorageClassificationNames.Count | Should be 2 

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Present" {
                
                $result = Test-TargetResource -Name $mockCloudName `
                                                -Description $mockDescription `
                                                -HostGroupNames $mockHostGroupNames `
                                                -ReadLibraryShareNames $mockReadLibraryShareNames `
                                                -PortClassificationNames $mockPortClassificationNames `
                                                -StorageClassificationNames $mockStorageClassificationNames `
                                                -LogicalNetworkNames $mockLogicalNetworkNames `
                                                -LoadBalancerNames $mockLoadBalancerNames `
                                                -Verbose

                $result | should be $true

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Absent but is Present" {

                $resultsFile = 'TestDrive:\results.txt'

                $result = Test-TargetResource -Ensure "Absent" `
                                                -Name $mockCloudName `
                                                -Description $mockDescription `
                                                -Verbose 4>$resultsFile

                $result | should be $false

                $resultsFile  | Should contain 'Expected Ensure'

                Assert-VerifiableMocks
            }

            It "Test-TargetResource tests failed" {

                $resultsFile = 'TestDrive:\results.txt'

                $result = Test-TargetResource -Name $mockCloudName `
                                                -Description "Fake Description" `
                                                -HostGroupNames @($mockHostGroupName2)`
                                                -ReadLibraryShareNames @($mockReadLibraryShareName1) `
                                                -PortClassificationNames @($mockPortClassificationName2) `
                                                -StorageClassificationNames @($mockStorageClassification1) `
                                                -LogicalNetworkNames @($mockLogicalNetworkName2) `
                                                -LoadBalancerNames @($mockLoadBalancerName1) `
                                                -Verbose 4>$resultsFile
                
                $result | should be $false

                $resultsFile | Should contain 'Expected Description'
                $resultsFile | Should contain 'Expected HostGroupNames'
                $resultsFile | Should contain 'Expected ReadLibraryShareNames'
                $resultsFile | Should contain 'Expected PortClassificationNames'
                $resultsFile | Should contain 'Expected StorageClassificationNames'
                $resultsFile | Should contain 'Expected LogicalNetworkNames'
                $resultsFile | Should contain 'Expected LoadBalancerNames'

                Assert-VerifiableMocks
            }
        }

        Context "Set Context Mocks" {

            #region Context Mocks

            Mock -ModuleName MSFT_xSCVMMCloud -CommandName Set-SCCloud {
                
                Write-Verbose "Mock Set-SCCloud $args"
                Write-Verbose "Mock Call Count: $Global:SetMockCount1"

                $Global:MockSetDescription = $Description
                $Global:MockSetHostGroups += $AddVMHostGroup
                $Global:MockSetReadableLibraryPaths += $AddReadOnlyLibraryShare
                
                $AddCloudResource | ForEach-Object {
                    
                    $resource = $_

                    switch($resource.ObjectType)
                    {
                        'PortClassification' {$Global:MockSetPortClassifications += $resource }

                        'StorageClassification' { $Global:MockSetStorageClassifications += $resource }

                        'LogicalNetwork' { $Global:MockSetLogicalNetworks += $resource }

                        'LoadBalancer' { $Global:MockSetLoadBalancers += $resource }

                        default { Write-Verbose "Classification Type: ""$($resource.ObjectType)"" not supported yet implemented" }
                    }
                }

                if($Global:SetMockCount1 -gt 0)
                {
                    $Global:MockSetHostGroupsNew = $AddVMHostGroup
                    $Global:MockSetReadableLibraryPathsNew = $AddReadOnlyLibraryShare

                    $AddCloudResource | ForEach-Object {
                        
                        $resource = $_

                        switch($resource.ObjectType)
                        {
                            'PortClassification' { $Global:MockSetPortClassificationsNew += $resource }

                            'StorageClassification' { $Global:MockSetStorageClassificationsNew += $resource }

                            'LogicalNetwork' { $Global:MockSetLogicalNetworksNew += $resource }

                            'LoadBalancer' { $Global:MockSetLoadBalancersNew += $resource }

                            default { Write-Verbose "Classification Type: ""$($resource.ObjectType)"" not supported yet implemented" }
                        }
                    }
                }

                $Global:SetMockCount1++
            }

            Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCCloud {

                Write-Verbose "Mock Get-SCCloud $args"
                Write-Verbose "Mock Call Count: $Global:GetMockCount1"

                if($Global:GetMockCount1 -ne 0)
                {
                    @{ Name = $mockCloudName
                        Description = $Global:MockSetDescription
                        HostGroup = $Global:MockSetHostGroups
                        ReadableLibraryPaths = $Global:MockSetReadableLibraryPaths
                        LogicalNetworks = $Global:MockSetLogicalNetworks
                        LoadBalancers = $Global:MockSetLoadBalancers
                        StorageClassifications = $Global:MockSetStorageClassifications
                        PortClassifications = $Global:MockSetPortClassifications
                    }
                }

                $Global:GetMockCount1++
            }

            #endregion

            BeforeEach {

                $Global:GetMockCount1  = 0
                $Global:SetMockCount1  = 0
                $Global:MockSetDescription = $null
                $Global:MockSetHostGroups =  @()
                $Global:MockSetReadableLibraryPaths =  @()
                $Global:MockSetStorageClassifications = @()
                $Global:MockSetPortClassifications = @()
                $Global:MockSetLoadBalancers = @()
                $Global:MockSetLogicalNetworks = @()
                $Global:MockSetHostGroupsNew =  @()
                $Global:MockSetReadableLibraryPathsNew =  @()
                $Global:MockSetStorageClassificationsNew = @()
                $Global:MockSetPortClassificationsNew = @()
                $Global:MockSetLoadBalancersNew = @()
                $Global:MockSetLogicalNetworksNew = @()
            }

            AfterEach {

                $Global:GetMockCount1  = 0
                $Global:SetMockCount1  = 0
                $Global:MockSetDescription = $null
                $Global:MockSetHostGroups =  @()
                $Global:MockSetReadableLibraryPaths =  @()
                $Global:MockSetStorageClassifications =  @()
                $Global:MockSetPortClassifications =  @()
                $Global:MockSetLoadBalancers =  @()
                $Global:MockSetLogicalNetworks =  @()
                $Global:MockSetHostGroupsNew = @()
                $Global:MockSetReadableLibraryPathsNew = @()
                $Global:MockSetStorageClassificationsNew = @()
                $Global:MockSetPortClassificationsNew = @()
                $Global:MockSetLoadBalancersNew = @()
                $Global:MockSetLogicalNetworksNew = @()
            }
            
            It "Set-TargetResource Present" {

                Set-TargetResource -Name $mockCloudName `
                                    -Description $mockDescription `
                                    -HostGroupNames $mockHostGroupNames `
                                    -ReadLibraryShareNames $mockReadLibraryShareNames `
                                    -LogicalNetworkNames $mockLogicalNetworkNames `
                                    -LoadBalancerNames $mockLoadBalancerNames `
                                    -StorageClassificationNames $mockStorageClassificationNames `
                                    -PortClassificationNames $mockPortClassificationNames `
                                    -Verbose

                Assert-VerifiableMocks
            }
                        
            It "Set-TargetResource Update" {

                Set-TargetResource -Name $mockCloudName `
                    -Description $mockDescription `
                    -HostGroupNames $mockHostGroupNames `
                    -ReadLibraryShareNames $mockReadLibraryShareNames `
                    -LogicalNetworkNames $mockLogicalNetworkNames `
                    -LoadBalancerNames $mockLoadBalancerNames `
                    -StorageClassificationNames $mockStorageClassificationNames `
                    -PortClassificationNames $mockPortClassificationNames `
                    -Verbose
                
                # Second Call does not re-set existing variables
                $mockGroupNames = $mockHostGroupNames + $mockHostGroupName3
                $mockLibraryNames = $mockReadLibraryShareNames + $mockReadLibraryShareName3 
                $mockNetworkNames = $mockLogicalNetworkNames + $mockLogicalNetworkName3
                $mockBalancerNames = $mockLoadBalancerNames + $mockLoadBalancerName3
                $mockStorageNames = $mockStorageClassificationNames + $mockStorageClassificationName3
                $mockPortNames = $mockPortClassificationNames + $mockPortClassificationName3

                Set-TargetResource -Name $mockCloudName `
                        -Description $mockDescription `
                        -HostGroupNames $mockGroupNames `
                        -ReadLibraryShareNames $mockLibraryNames `
                        -LogicalNetworkNames $mockNetworkNames `
                        -LoadBalancerNames $mockBalancerNames `
                        -StorageClassificationNames $mockStorageNames `
                        -PortClassificationNames $mockPortNames `
                        -Verbose
                
                $Global:MockSetHostGroupsNew.Count | Should be 1
                $Global:MockSetReadableLibraryPathsNew.Count | Should be 1
                $Global:MockSetStorageClassificationsNew.Count | Should be 1
                $Global:MockSetPortClassificationsNew.Count | Should be 1
                $Global:MockSetLoadBalancersNew.Count | Should be 1
                $Global:MockSetLogicalNetworksNew.Count | Should be 1

                Assert-VerifiableMocks
            }

            It "Set-TargetResource one optional parameter at a time - Description" {

                Set-TargetResource -Name $mockCloudName `
                        -Description $mockDescription `
                        -Verbose

                Assert-VerifiableMocks
            }

            It "Set-TargetResource one optional parameter at a time - HostGroupNames" {

                Set-TargetResource -Name $mockCloudName `
                        -HostGroupNames $mockHostGroupNames `
                        -Verbose

                Assert-VerifiableMocks
            }

      
            It "Set-TargetResource one optional parameter at a time - ReadLibraryShareNames" {

                Set-TargetResource -Name $mockCloudName `
                        -ReadLibraryShareNames $mockReadLibraryShareNames `
                        -Verbose

                Assert-VerifiableMocks
            }

            It "Set-TargetResource one optional parameter at a time - LogicalNetworkNames" {

                Set-TargetResource -Name $mockCloudName `
                        -LogicalNetworkNames $mockLogicalNetworkNames `
                        -Verbose

                Assert-VerifiableMocks
            }

            It "Set-TargetResource one optional parameter at a time - LoadBalancerNames" {

                Set-TargetResource -Name $mockCloudName `
                        -LoadBalancerNames $mockLoadBalancerNames `
                        -Verbose

                Assert-VerifiableMocks
            }

            It "Set-TargetResource one optional parameter at a time - PortClassificationNames" {

                Set-TargetResource -Name $mockCloudName `
                        -PortClassificationNames $mockPortClassificationNames `
                        -Verbose

                Assert-VerifiableMocks
            }

            It "Set-TargetResource one optional parameter at a time - StorageClassificationNames" {

                Set-TargetResource -Name $mockCloudName `
                        -StorageClassificationNames $mockStorageClassificationNames `
                        -Verbose

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Present but is Absent" {

                $result = Test-TargetResource -Name $mockCloudName -Verbose

                $result | Should be $false 

                Assert-VerifiableMocks
            }
        }
   
        Context "Mock Context" {

            #region Context Mocks

            Mock -ModuleName MSFT_xSCVMMCloud -CommandName Get-SCCloud {

                Write-Verbose "Mock Get-SCCloud $args"
                Write-Verbose "Mock Call Count: $Global:GetMockCount2"

                if($Global:GetMockCount2 -eq 0)
                {
                    @{ Name = $mockCloudName }
                }

                $Global:GetMockCount2++
            }

            #endregion

            BeforeEach {

                $Global:GetMockCount2  = 0
            }

            AfterEach {

                $Global:GetMockCount2  = 0
            }

            It "Set-TargetResource Absent" {

                Set-TargetResource -Ensure 'Absent' `
                                    -Name $mockCloudName `
                                    -Verbose

                Assert-VerifiableMocks
            }
        }
    }
}

Get-Module -Name MSFT_xSCVMMCloud | Remove-Module
Get-Module -Name VirtualMachineManager | Remove-Module