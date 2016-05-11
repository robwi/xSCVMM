<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMHostGroup.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

# Create Empty Mockable Modules that dont exist on a default windows install
Get-Module -Name VirtualMachineManager | Remove-Module

New-Module -Name VirtualMachineManager -ScriptBlock `
{
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function New-SCVMHostGroup
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $Description,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Remove-SCVMHostGroup
    {
        [CmdletBinding()]
        param
        (
            $VmHostGroup,
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

    Export-ModuleMember -Function *
} | Import-Module -Force  

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$TestModule = "$here\..\MSFT_xSCVMMHostGroup.psm1"

If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}

InModuleScope MSFT_xSCVMMHostGroup {

    $mockHostGroupName = "mock Name"
    $mockDescription = "Description"
    $mockHostGroupPath = "All Hosts\$mockHostGroupName"
    $mockHostGroup = @{ Name=$mockHostGroupName; Path=$mockHostGroupPath; Description=$mockDescription } 

    Describe "MSFT_xSCVMMHostGroup Tests" {

        Mock -ModuleName SCVMMHelper  -CommandName Get-SCVMMServer -Verifiable {

            Write-Verbose "Mock Get-SCVMMServer $args"

            "LibraryServer"
        }

        Mock -ModuleName MSFT_xSCVMMHostGroup -CommandName Remove-SCVMHostGroup { }

        Mock -ModuleName MSFT_xSCVMMHostGroup -CommandName New-SCVMHostGroup { }
  
        Mock -ModuleName MSFT_xSCVMMHostGroup -CommandName Get-SCVMHostGroup {
        
            $mockHostGroup
        }
     
        Context "No context mocks" {

            It "Get-TargetResource Present" {

                $result = Get-TargetResource -Name $mockHostGroupName -Verbose

                $result.Name | Should be $mockHostGroupName
                $result.Path | Should be $mockHostGroupPath
                $result.Description | Should be $mockDescription

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Present" {

                $result = Test-TargetResource -Name $mockHostGroupName -Description $mockDescription -Verbose

                $result | Should be $true

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Absent but is Present" {

                $result = Test-TargetResource -Ensure Absent -Name $mockHostGroupName -Description $mockDescription -Verbose

                $result | Should be $false

                Assert-VerifiableMocks
            }
                
            It "Set-TargetResource Present" {

                Set-TargetResource -Name $mockHostGroupName -Description $mockDescription -Verbose

                Assert-MockCalled -ModuleName MSFT_xSCVMMHostGroup -CommandName New-SCVMHostGroup -ParameterFilter { $name -eq $mockHostGroupName } -Exactly 1

                Assert-VerifiableMocks
            }
        }
   
        Context "Mock return host group first get only" {

            Mock -ModuleName MSFT_xSCVMMHostGroup -CommandName Get-SCVMHostGroup -ParameterFilter { $name -eq $mockHostGroupName } {
            
                if($Global:MethodCount -eq 0)
                {
                    $mockHostGroup 
                }

                $Global:MethodCount++
            } 

            BeforeEach {

                $Global:MethodCount = 0
            }

            AfterEach {

                $Global:MethodCount = 0
            }

            It "Set-TargetResource Absent" {

                Set-TargetResource -Ensure Absent -Name $mockHostGroupName -Verbose

                Assert-MockCalled -ModuleName MSFT_xSCVMMHostGroup -CommandName Remove-SCVMHostGroup  -Exactly 1

                Assert-VerifiableMocks
            }
        }

        Context "Mock no host group" {
            
            Mock -ModuleName MSFT_xSCVMMHostGroup -CommandName Get-SCVMHostGroup { }

            It "Get-TargetResource Absent" {
            
                $result = Get-TargetResource -Name $mockHostGroupName -Verbose

                $result.Ensure | Should be "Absent"

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Absent" {

                $result = Test-TargetResource -Ensure Absent -Name $mockHostGroupName -Verbose

                $result | Should be $true

                Assert-VerifiableMocks
            }
        }
    }
}

# Remove Mock Modules
Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name MSFT_xSCVMMHostGroup | Remove-Module


