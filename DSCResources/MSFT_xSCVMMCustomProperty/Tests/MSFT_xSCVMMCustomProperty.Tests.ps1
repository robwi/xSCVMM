<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMCustomProperty

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

#region Shell Modules
Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    function Get-SCCustomProperty
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function New-SCCustomProperty
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $Description,
            $AddMember,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Set-SCCustomProperty
    {
        [CmdletBinding()]
        param
        (
            $CustomProperty,
            $Description,
            $AddMember,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Remove-SCCustomProperty
    {
        [CmdletBinding()]
        param
        (
            $CustomProperty,
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
#endregion 

#region Load Test Files
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$testModule = "$here\..\MSFT_xSCVMMCustomProperty.psm1"

If (Test-Path $testModule)
{
    Import-Module $testModule -Force -ErrorAction Stop
}
Else
{
    Throw "Unable to find '$testModule'"
}
#endregion

InModuleScope MSFT_xSCVMMCustomProperty {
    
    #region Mock Variables

    $mockPropertyName = "MockPropertyName"
    $mockDescription = "Mock Description"
    $mockMembers = @("Cloud","VM","VMHost")
    
    #endregion

    Describe "MSFT_xSCVMMCustomProperty Tests" {
        
        #region Describe Mocks
        Mock -ModuleName SCVMMHelper  -CommandName Get-SCVMMServer -Verifiable {

            Write-Verbose "Mock Get-SCVMMServer $args"

            "LibraryServer"
        }

        Mock -ModuleName MSFT_xSCVMMCustomProperty -CommandName Get-SCCustomProperty {

            Write-Verbose "Mock Get-SCCustomProperty $args"

            @{
                Name=$mockPropertyName
                Description=$mockDescription
                Members=$mockMembers }
        }

        Mock -ModuleName MSFT_xSCVMMCustomProperty -CommandName New-SCCustomProperty {

            Write-Verbose "Mock New-SCCustomProperty $args"
        }

        Mock -ModuleName MSFT_xSCVMMCustomProperty -CommandName Set-SCCustomProperty {

            Write-Verbose "Mock Set-SCCustomProperty $args"
        }

        Mock -ModuleName MSFT_xSCVMMCustomProperty -CommandName Remove-SCCustomProperty {

            Write-Verbose "Mock Remove-SCCustomProperty $args"
        }

        #endregion

        Context "No Context Mocks" {

            It "Get-TargetResource Present" {

                $result = Get-TargetResource -Name $mockPropertyName `
                                            -Members $mockMembers `
                                            -Description $mockDescription `
                                            -Verbose

                $result.Name | Should be $mockPropertyName
                $result.Members | Should be $mockMembers
                $result.Description | Should be $mockDescription

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Present" {
               
                $result = Test-TargetResource -Name $mockPropertyName `
                                            -Members $mockMembers `
                                            -Description $mockDescription `
                                            -Verbose

                $result | Should be $true

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Absent but is Present" {

                $resultsFile = "TestDrive:\result.txt"

                $result = Test-TargetResource -Ensure 'Absent' `
                                            -Name $mockPropertyName `
                                            -Members $mockMembers `
                                            -Description $mockDescription `
                                            -Verbose 4>$resultsFile

                $resultsFile | should contain "Absent"
               
                $result | Should be $false

                Assert-VerifiableMocks
            }
        
            It "Test-TargetResource invalid member" {

                { Test-TargetResource -Name $mockPropertyName -Members @("BadInput") -Verbose } | `
                Should throw "BadInput"
            }


            It "Test-TargetResource wrong description" {
                
                $resultsFile = "TestDrive:\result.txt"

                $result = Test-TargetResource -Name $mockPropertyName `
                                            -Members $mockMembers `
                                            -Description "Bad Description" `
                                            -Verbose 4>$resultsFile

                $resultsFile | should contain "Bad Description"

                $result | Should be $false

                Assert-VerifiableMocks
            }

            It "Test-TargetResource wrong members" {
                
                $resultsFile = "TestDrive:\result.txt"

                $result = Test-TargetResource -Name $mockPropertyName -Members @("Cloud") -Verbose 4>$resultsFile

                $resultsFile | should contain "do not match expected values"

                $result | Should be $false

                Assert-VerifiableMocks
            }
        }
        
        Context "Set Context Mocks" {
            
            #region Context Mocks
            Mock -ModuleName MSFT_xSCVMMCustomProperty -CommandName Get-SCCustomProperty {

                Write-Verbose "Mock Get-SCCustomProperty $args"
                Write-Verbose "Mock Call Count: $Global:MockCount"

                if($Global:MockCount -ne 0)
                {       
                    @{
                        Name=$mockPropertyName
                        Description=$mockDescription
                        Members=$mockMembers }
                }

                $Global:MockCount++
            }

            #endregion

            BeforeEach {

                $Global:MockCount  = 0
            }

            AfterEach {

                $Global:MockCount  = 0
            }
            
            It "Set-TargetResource Present - All" {
                
                Set-TargetResource -Name $mockPropertyName `
                                            -Members $mockMembers `
                                            -Description $mockDescription `
                                            -Verbose

               

                Set-TargetResource -Name $mockPropertyName `
                                            -Members $mockMembers `
                                            -Description $mockDescription `
                                            -Verbose

                Assert-MockCalled New-SCCustomProperty 1
                Assert-MockCalled Set-SCCustomProperty 1 -ParameterFilter { $Members -eq $null }

                Assert-VerifiableMocks
            }
        }
        

        Context "Absent Context Mocks" {

            #region Context Mocks

            Mock -ModuleName MSFT_xSCVMMCustomProperty -CommandName Get-SCCustomProperty {

                Write-Verbose "Mock Get-SCCustomProperty $args"
                Write-Verbose "Mock Call Count: $Global:MockCount"

                if($Global:MockCount -eq 0)
                {
                    @{
                        Name=$mockPropertyName
                        Description=$mockDescription
                        Members=$mockMembers }
                }

                $Global:MockCount++
            }

            #endregion

            BeforeEach {

                $Global:MockCount  = 0
            }

            AfterEach {

                $Global:MockCount  = 0
            }

            It "Set-TargetResource Absent" {

                Set-TargetResource -Ensure 'Absent' `
                                -Name $mockPropertyName `
                                -Members $mockMembers `
                                -Verbose

                Assert-MockCalled Remove-SCCustomProperty 1

                Assert-VerifiableMocks
            }
        }
    }
}

Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name MSFT_xSCVMMCustomProperty | Remove-Module