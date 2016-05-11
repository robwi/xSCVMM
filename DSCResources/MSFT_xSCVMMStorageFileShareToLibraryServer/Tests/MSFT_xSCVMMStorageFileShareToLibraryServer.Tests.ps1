<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMStorageFileShareToLibraryServer .psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

#region Shell Modules
Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    function Register-SCStorageFileShare
    {
        [CmdletBinding()]
        param
        (
            $LibraryServer,
            $StorageFileShare,
            $ErrorActionPreference
        )
    }

    function UnRegister-SCStorageFileShare
    {
        [CmdletBinding()]
        param
        (
            $LibraryServer,
            $StorageFileShare,
            $ErrorActionPreference
        )
    }

    function Get-SCLibraryServer
    {
        [CmdletBinding()]
        param
        (
            $ComputerName,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Get-SCStorageFileServer
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
    }

    Export-ModuleMember -Function *
} | Import-Module -Force

#endregion 

#region Load Test Files
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$testModule = "$here\..\MSFT_xSCVMMStorageFileShareToLibraryServer.psm1"

If (Test-Path $testModule)
{
    Import-Module $testModule -Force -ErrorAction Stop
}
Else
{
    Throw "Unable to find '$testModule'"
}
#endregion

InModuleScope MSFT_xSCVMMStorageFileShareToLibraryServer  {
    
    #region Mock Variables

    $mockLibraryServerName = "MockLibraryServer"
    $mockFileServerName = "MockLibraryServer"
    $mockFileShareName1 = "MockShare1"
    $mockFileShareName2 = "MockShare2"
    $mockSharePath1 = "\\Share1"
    $mockSharePath2 = "\\Share2"
    
    $mockFileShare1 = @{ Name=$mockFileShareName1; SharePath=$mockSharePath1; LibraryServer=$mockLibraryServerName }
    $mockFileShare2 = @{ Name=$mockFileShareName2; SharePath=$mockSharePath2 }
    
    #endregion

    Describe "MSFT_xSCVMMStorageLibraryShare Tests" {
        
        #region Describe Mocks
        Mock -ModuleName SCVMMHelper  -CommandName Get-SCVMMServer -Verifiable {

            Write-Verbose "Mock Get-SCVMMServer $args"

            "LibraryServer"
        }

        Mock -ModuleName MSFT_xSCVMMStorageFileShareToLibraryServer  -CommandName Register-SCStorageFileShare {

            Write-Verbose "Mock Register-SCStorageFileShare $args"
        }
     
        Mock -ModuleName MSFT_xSCVMMStorageFileShareToLibraryServer  -CommandName UnRegister-SCStorageFileShare {

            Write-Verbose "Mock UnRegister-SCStorageFileShare $args"
        }

        Mock -ModuleName MSFT_xSCVMMStorageFileShareToLibraryServer  -CommandName Get-SCLibraryServer {

            Write-Verbose "Mock Get-SCLibraryServer $args"

            @{ Name = $ComputerName } 
        }

        Mock -ModuleName MSFT_xSCVMMStorageFileShareToLibraryServer  -CommandName Get-SCStorageFileServer {

            Write-Verbose "Mock Get-SCStorageFileServer $args"

            @{ Name = $Name 
                StorageFileShares = @($mockFileShare1, $mockFileShare2) } 
        }

        #endregion

        Context "No Context Mocks" {

            It "Get-TargetResource Present" {

                $result = Get-TargetResource -FileShareName $mockFileShareName1 `
                                            -LibraryServerName $mockLibraryServerName `
                                            -FileServerName $mockFileServerName `
                                            -Verbose

                $result.Ensure | Should be "Present"
                $result.FileShareName | Should be $mockFileShareName1
                $result.LibraryServerName | Should be $mockLibraryServerName
                $result.FileServerName | Should be $mockFileServerName
                $result.FileSharePath | Should be $mockSharePath1

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Present" {

                $result = Test-TargetResource -FileShareName $mockFileShareName1 `
                                            -LibraryServerName $mockLibraryServerName `
                                            -FileServerName $mockFileServerName `
                                            -Verbose

                $result | Should be $true

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Absent but is Present" {

                $result = Test-TargetResource -Ensure 'Absent' `
                                            -FileShareName $mockFileShareName1 `
                                            -LibraryServerName $mockLibraryServerName `
                                            -FileServerName $mockFileServerName `
                                            -Verbose

                $result | Should be $false

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Absent with no Association" {
                 
                $result = Test-TargetResource -Ensure 'Absent' `
                                            -FileShareName $mockFileShareName2 `
                                            -LibraryServerName $mockLibraryServerName `
                                            -FileServerName $mockFileServerName `
                                            -Verbose

                $result | Should be $true

                Assert-VerifiableMocks
            }

        }

        Context "Set Context Mocks" {
            
            #region Context Mocks 

            Mock -ModuleName MSFT_xSCVMMStorageFileShareToLibraryServer  -CommandName Get-SCStorageFileServer {

                Write-Verbose "Mock Get-SCStorageFileServer $args"
                Write-Verbose "Mock Call Count: $Global:MockCount"

                if($Global:MockCount -ne 0)
                {
                    $mockShareWithAssociation = @{ Name=$mockFileShareName1
                                                    SharePath=$mockSharePath1
                                                    LibraryServer=$mockLibraryServerName}

                    @{ Name = $Name; StorageFileShares = @($mockShareWithAssociation) } 

                }
                else
                {
                    $mockShareNoAssociation = @{ Name=$mockFileShareName1
                                                    SharePath=$mockSharePath1
                                                    LibraryServer=$null }

                    @{ Name = $Name; StorageFileShares = @($mockShareNoAssociation) } 
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
            
            It "Set-TargetResource Present" {
                
                Set-TargetResource -FileShareName $mockFileShareName1 `
                                    -LibraryServerName $mockLibraryServerName `
                                    -FileServerName $mockFileServerName `
                                    -Verbose

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Present but is Absent" {

                $result = Test-TargetResource -Ensure 'Present' `
                                                -FileShareName $mockFileShareName1 `
                                                -LibraryServerName $mockLibraryServerName `
                                                -FileServerName $mockFileServerName `
                                                -Verbose

                $result | Should be $false

                Assert-VerifiableMocks
            }
        }
   
        Context "Absent Context Mocks" {

            #region context mocks 

            mock -modulename MSFT_xSCVMMStorageFileShareToLibraryServer  -commandname Get-SCStorageFileServer {

                Write-Verbose "Mock Get-SCStorageFileServer $args"
                Write-Verbose "Mock Call Count: $Global:MockCount"

                if($Global:MockCount -eq 0)
                {
                    $mockShareWithAssociation = @{ Name=$mockFileShareName1
                                                    SharePath=$mockSharePath1
                                                    LibraryServer=$mockLibraryServerName}

                    @{ Name = $Name; StorageFileShares = @($mockShareWithAssociation) } 

                }
                else
                {
                    $mockShareNoAssociation = @{ Name=$mockFileShareName1
                                                    SharePath=$mockSharePath1
                                                    LibraryServer=$null }

                    @{ Name = $Name; StorageFileShares = @($mockShareNoAssociation) } 
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
                                    -FileShareName $mockFileShareName1 `
                                    -LibraryServerName $mockLibraryServerName `
                                    -FileServerName $mockFileServerName `
                                    -Verbose

                Assert-VerifiableMocks
            }
        }
    }
}

Get-Module -Name MSFT_xSCVMMStorageFileShareToLibraryServer  | Remove-Module
Get-Module -Name VirtualMachineManager | Remove-Module