<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMHostCluster.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>


# Create Empty Mockable Modules that dont exist on a default windows install
Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function Get-SCVMMServer
    {
        [CmdletBinding()]
        param
        (
            $ComputerName,
            $ErrorActionPreference
        )
    }

    function Get-SCVMHostCluster
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCRunAsAccount 
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCVMHostGroup 
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $Id,
            $ErrorActionPreference
        )
    }

    function Add-SCVMHostCluster 
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMHostGroup,
            $VMMServer,
            $ClusterReserve,
            $Credential,
            $ErrorActionPreference
        )
    }

    function Add-SCVMHost 
    {
        [CmdletBinding()]
        param
        (
            $ComputerName,
            $Credential,
            $VMHostCluster,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Remove-SCVMHostCluster 
    {
        [CmdletBinding()]
        param
        (
            $VMHostCluster,
            $Credential,
            $ErrorActionPreference,
            [switch] $Force
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force

Get-Module -Name FailoverClusters | Remove-Module
New-Module -Name FailoverClusters -ScriptBlock `
{
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function Get-ClusterNode
    {
        [CmdletBinding()]
        param
        (
            $ErrorActionPreference
        )
    }

    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function Get-Cluster
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $ErrorActionPreference
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$TestModule = "$here\..\MSFT_xSCVMMHostCluster.psm1"

If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}

# InModuleScope allows you to call private functions
InModuleScope MSFT_xSCVMMHostCluster {

    # Test Variables
    $mockPassword =  ConvertTo-SecureString -String "fakePassword" -AsPlainText -Force
    $mockUser = "FakeUser"
    $mockVMMServerName = "Mock-VMM-Server"
    $mockComputerName1 = "Computer1"
    $mockComputerName2 = "Computer2"
    $mockComputerName3 = "Computer3"
    $mockVMNode1 = @{Name = ($mockComputerName1 + "." + $mockDomainName); OverallStateString = 'OK'}
    $mockVMNode2 = @{Name = ($mockComputerName2 + "." + $mockDomainName); OverallStateString = 'OK'}
    $mockVMNode3 = @{Name = ($mockComputerName3 + "." + $mockDomainName); OverallStateString = 'OK'}
    $mockPendingVMNode3 = @{Name = ($mockComputerName3 + "." + $mockDomainName); OverallStateString = 'Pending'}
    $mockClusterName = "Cluster 1"
    $mockHostGroupName = "Mock Host Group"

    $mockManagementCredentialName = "MockRunAsCred"
    $mockClusterReserve = 2
    $mockHostGroupName = "Mock Host Group"

    Describe "MSFT_xSCVMMHostCluster Tests" {

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostGroup {

            Write-Verbose "Mock Get-SCVMHostGroup $args"

            @{ Name = $mockHostGroupName; }
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-ClusterNode {

            Write-Verbose "Mock Get-ClusterNode $args"

            @{ Name = $mockComputerName1 }
            @{ Name = $mockComputerName2 }
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-Cluster {
            
            Write-Verbose "Mock Get-Cluster $args"

            @{ Name = $mockClusterName }
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMMServer {

            Write-Verbose "Mock Get-SCVMMServer $args"

            @{ VMMConnection = "Mock VMMConnection"} 
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCRunAsAccount {

            Write-Verbose "Mock Get-SCRunAsAccount $args"

            @{ UserName = $mockManagementCredentialName } 
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostCluster {

            Write-Verbose "Mock Get-SCVMHostCluster $args"

            @{ 
                ClusterReserve = $mockClusterReserve; 
                VMHostManagementCredential = $mockManagementCredentialName; 
                HostGroup=$mockHostGroupName
                ClusterName=$mockClusterName
                Nodes=@($mockVMNode1, $mockVMNode2)
                DomainName=$mockDomainName } 
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Add-SCVMHost {

            Write-Verbose "Mock Add-SCVMHost  $args"
        }


        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Add-SCVMHostCluster {

            Write-Verbose "Mock Add-SCVMHostCluster $args"
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Invoke-Command `
            -ParameterFilter { $ScriptBlock -eq ${Function:Set-HostClusterOnVMMServer} } {
            
            Write-Verbose "Mock Invoke-Command."

            Set-HostClusterOnVMMServer `
                $Ensure $HostGroupName $ManagementCredentialName $ClusterReserve $ClusterName $WindowsClusterNodeNames `
                ${Function:Get-ConnectionAndClusterOnVMMServer} $VerbosePreference
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Invoke-Command `
            -ParameterFilter { $ScriptBlock -eq ${Function:Get-ConnectionAndClusterOnVMMServer} } {

            Write-Verbose "Mock Invoke-Command."

            Get-ConnectionAndClusterOnVMMServer $ClusterName $VerbosePreference
        }

        Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Remove-SCVMHostCluster -ParameterFilter { $Credential -ne $null } {
        
            Write-Verbose "Mock Remove-SCVMHostCluster $args"
        }

        Context "no context mocks" {

            It "Get-TargetResource Present" {

                $result = Get-TargetResource -Ensure Present `
                                            -HostGroupName $mockHostGroupName `
                                            -ManagementCredentialName $mockManagementCredentialName `
                                            -ClusterReserve $mockClusterReserve `
                                            -VMMServerName $mockVMMServerName `
                                            -Verbose

                $result.Ensure | Should be "Present"
                $result.ClusterName | Should be $mockClusterName
                $result.HostGroupName | Should be $mockHostGroupName
                $result.HostGroupPath | Should be $mockHostGroupPath
                $result.ClusterReserve | Should be $mockClusterReserve
                $result.DomainName | Should be $mockDomainName
                $result.NodeNames | Should be @($mockVMNode1.Name,$mockVMNode2.Name)
                $result.HasPendingNodes | Should be $false
            }

            It "Test-TargetResource Present" {

                $result = Test-TargetResource `
                    -Ensure Present `
                    -HostGroupName $mockHostGroupName `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -ClusterReserve $mockClusterReserve `
                    -VMMServerName $mockVMMServerName `
                    -Verbose

                $result | Should be $true
            }

            It "Test-TargetResource Expected Absent but is Present" {

                $result = Test-TargetResource -Ensure Absent -ManagementCredentialName $mockManagementCredentialName `
                                -VMMServerName $mockVMMServerName -Verbose

                $result | Should be $false
            }

            It "Set-TargetResource already exists refresh" {

                Set-TargetResource `
                    -Ensure Present `
                    -HostGroupName $mockHostGroupName `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -ClusterReserve $mockClusterReserve `
                    -VMMServerName $mockVMMServerName `
                    -Verbose
            }
        }

        Context "Mock wrong node count" {

            #Bad Data Mock
            Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostCluster {

                Write-Verbose "Mock Get-SCVMHostCluster $args"

                @{ ClusterReserve = $mockClusterReserve
                    ManagementCredential = $mockManagementCredentialName
                    HostGroup=$mockHostGroupName
                    ClusterName=$mockClusterName
                    DomainName=$mockDomainName
                    Nodes=@($mockVMNode1)} 
            }

            It "Test-TargetResource tests failed" {

                $resultsFile = 'TestDrive:\results.txt'

                $result = Test-TargetResource `
                    -Ensure Present `
                    -HostGroupName "Junk Host Group Name" `
                    -ManagementCredentialName "Junk" `
                    -ClusterReserve 99 `
                    -VMMServerName $mockVMMServerName `
                    -Verbose 4>$resultsFile

                $result | Should be $false
                
                $resultsFile  | Should contain 'Expected HostGroup'
                $resultsFile  | Should contain 'Expected ClusterReserve'
                $resultsFile | Should contain 'values not found in right side'
            }
        }

        Context "Mock return VMM cluster second get only" {

            BeforeEach {

               $Global:GetSCVMHostClusterCount = 0
            }

            AfterEach {

               $Global:GetSCVMHostClusterCount = 0
            }

            # First time VMM Cluster does not exist and is then added
            Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostCluster {

                Write-Verbose "Mock Get-SCVMHostCluster $args"

                if($Global:GetSCVMHostClusterCount -eq 1)
                {
                    @{ ClusterReserve = $mockClusterReserve; 
                        VMHostManagementCredential = $mockManagementCredentialName; 
                        HostGroup=$mockHostGroupName
                        ClusterName=$mockClusterName
                        Nodes=@($mockVMNode1, $mockVMNode2)
                        DomainName=$mockDomainName } 
                }   
                
                $Global:GetSCVMHostClusterCount++    
            }
            
            It "Set-TargetResource Present" {

                Set-TargetResource `
                    -Ensure Present `
                    -HostGroupName $mockHostGroupName `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -ClusterReserve $mockClusterReserve `
                    -VMMServerName $mockVMMServerName `
                    -Verbose
            }
        }
   
        Context "Mock return VMM cluster first get only" {

            BeforeEach {

               $Global:GetSCVMHostClusterCount = 0
            }

            AfterEach {

               $Global:GetSCVMHostClusterCount = 0
            }

            # First time VMM Cluster Exists and is then removed
            Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostCluster {
                
                Write-Verbose "Mock Get-SCVMHostCluster $args"

                if($Global:GetSCVMHostClusterCount -eq 0)
                {
                     @{ ClusterReserve = $mockClusterReserve; 
                        VMHostManagementCredential = $mockManagementCredentialName; 
                        HostGroup=$mockHostGroupName
                        ClusterName=$mockClusterName
                        Nodes=@($mockVMNode1, $mockVMNode2)
                        DomainName=$mockDomainName } 
                }   
                
                $Global:GetSCVMHostClusterCount++   
            }

            It "Set-TargetResource Absent" {

                Set-TargetResource `
                    -Ensure Absent `
                    -HostGroupName $null `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -ClusterReserve $null `
                    -VMMServerName $mockVMMServerName `
                    -Verbose

                Assert-MockCalled -ModuleName MSFT_xSCVMMHostCluster -CommandName Remove-SCVMHostCluster -Exactly 1
            }
        }

        Context "Mock no VMM cluster" {
            
            # Absent
            Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostCluster {

                Write-Verbose "Mock Get-SCVMHostCluster $args"  
            }
        }

        Context "Mock Pending nodes" {

            BeforeEach {

                $Global:GetSCVMHostClusterCount = 0
            }

            AfterEach {

                $Global:GetSCVMHostClusterCount = 0
            }

            # Pending Nodes
            Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-SCVMHostCluster {

                Write-Verbose "Mock Get-SCVMHostCluster $args"

                # First time node count mismatch and 1 pending node
                if($Global:GetSCVMHostClusterCount -eq 0)
                {
                    @{ ClusterReserve = $mockClusterReserve
                        VMHostManagementCredential = $mockManagementCredentialName
                        HostGroup=$mockHostGroupName
                        ClusterName=$mockClusterName
                        Nodes=@($mockVMNode1,$mockVMPendingNode3)
                        DomainName=$mockDomainName } 
                }
                # Then Success
                else
                {
                    @{ ClusterReserve = $mockClusterReserve
                        VMHostManagementCredential = $mockManagementCredentialName
                        HostGroup=$mockHostGroupName
                        ClusterName=$mockClusterName
                        Nodes=@($mockVMNode1, $mockVMNode2, $mockVMNode3)
                        DomainName=$mockDomainName } 
                }

                $Global:GetSCVMHostClusterCount++ 
            }

            
            Mock -ModuleName MSFT_xSCVMMHostCluster -CommandName Get-ClusterNode {

                Write-Verbose "Mock Get-ClusterNode $args"

                @{ Name = $mockComputerName1 }
                @{ Name = $mockComputerName2 }
                @{ Name = $mockComputerName3 }
            }

            It "Set-TargetResource Pending nodes" {

                Set-TargetResource `
                    -Ensure Present `
                    -HostGroupName $mockHostGroupName `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -ClusterReserve $mockClusterReserve `
                    -VMMServerName $mockVMMServerName `
                    -Verbose

                Assert-MockCalled -CommandName Add-SCVMHost -Exactly 2
            }
        }
    }
}

# Remove Mock Modules
Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name FailoverClusters | Remove-Module
Get-Module -Name MSFT_xSCVMMHostCluster | Remove-Module


