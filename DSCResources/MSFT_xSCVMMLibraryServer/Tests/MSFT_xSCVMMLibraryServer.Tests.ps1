<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCVMMLibraryServer.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

# Create Empty Mockable Modules that dont exist on a default windows install
Get-Module -Name VirtualMachineManager | Remove-Module
New-Module -Name VirtualMachineManager -ScriptBlock `
{
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
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
            $Id,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Remove-SCLibraryServer
    {
        [CmdletBinding()]
        param
        (
            $LibraryServer,
            $Credential,
            $ErrorActionPreference
        )
    }

    function Set-SCLibraryServer
    {
        [CmdletBinding()]
        param
        (
            $LibraryServer,
            $VMHostGroup,
            $Description,
            $EnableUnencryptedFileTransfer,
            $LibraryServerManagementCredential,
            $VMMServer,
            $ErrorActionPreference
        )
    }

    function Add-SCLibraryServer
    {
        [CmdletBinding()]
        param
        (
            $ComputerName,
            $VMHostGroup,
            $Description,
            $EnableUnencryptedFileTransfer,
            $Credential,
            $VMMServer,
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

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$testModule = "$here\..\MSFT_xSCVMMLibraryServer.psm1"

If (Test-Path $testModule)
{
    Import-Module $testModule -Force -ErrorAction Stop
}
Else
{
    Throw "Unable to find '$testModule'"
}

InModuleScope MSFT_xSCVMMLibraryServer {

    $mockHostGroupName = 'Mock Host Group'
    $mockManagementCredentialName = 'MockRunAsCred'
    $mockDescription = 'Mock Description'
    $mockServerName = 'MockServerName'
    $mockHostGroupId = 1234

    Describe "MSFT_xSCVMMLibraryServer Tests" {

        Mock -ModuleName SCVMMHelper  -CommandName Get-SCVMMServer -Verifiable {

            Write-Verbose "Mock Get-SCVMMServer $args"

            "LibraryServer"
        }

        Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Get-SCRunAsAccount {

            Write-Verbose "Mock Get-SCRunAsAccount $args"

            @{ UserName = $mockManagementCredentialName } 
        }

        Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Get-SCVMHostGroup {

            Write-Verbose "Mock Get-SCVMHostGroup $args"

            @{ Name = $mockHostGroupName; }
        }

        Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Remove-SCLibraryServer {

            Write-Verbose "Mock Remove-SCLibraryServer $args"
        }

        Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Set-SCLibraryServer {

            Write-Verbose "Mock Set-SCLibraryServer $args"
        }

        Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Add-SCLibraryServer {

            Write-Verbose "Mock Set-SCLibraryServer $args"
        }

        Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Get-SCLibraryServer {

            Write-Verbose "Mock Get-SCLibraryServer $args"

            @{ ComputerName = $mockServerName; 
                Description = $mockDescription 
                HostGroupId = $mockHostGroupId
                LibraryServerManagementCredential = $mockManagementCredentialName }
        }

        Context "No Context Mocks" {

            It "Get-TargetResource Present" {
                $result = Get-TargetResource -ServerName $MockServerName `
                                    -EnableUnencryptedFileTransfer $false `
                                    -ManagementCredentialName $mockManagementCredentialName `
                                    -HostGroupName $mockHostGroupName `
                                    -Description $mockDescription `
                                    -Verbose

                $result.Description | Should be $mockDescription
                $result.ServerName | Should be $mockServerName
                $result.HostGroupName | Should be $mockHostGroupName
                $result.ManagementCredentialName | Should be $mockManagementCredentialName

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Present" {

                $result = Test-TargetResource -ServerName $MockServerName `
                                            -EnableUnencryptedFileTransfer $false `
                                            -ManagementCredentialName $mockManagementCredentialName `
                                            -HostGroupName $mockHostGroupName `
                                            -Description $mockDescription `
                                            -Verbose

                $result | Should be $true

                Assert-VerifiableMocks
            }

            It "Test-TargetResource Expected Absent but is Present" {

                $result = Test-TargetResource -Ensure 'Absent' `
                                            -ServerName $MockServerName `
                                            -EnableUnencryptedFileTransfer $false `
                                            -ManagementCredentialName $mockManagementCredentialName `
                                            -HostGroupName $mockHostGroupName `
                                            -Description $mockDescription `
                                            -Verbose

                $result | Should be $false

                Assert-VerifiableMocks
            }

            It "Set-TargetResource Update existing" {

                Set-TargetResource -ServerName $mockServerName `
                                            -EnableUnencryptedFileTransfer $false `
                                            -ManagementCredentialName $mockManagementCredentialName `
                                            -HostGroupName $mockHostGroupName `
                                            -Description $mockDescription `
                                            -Verbose

                Assert-VerifiableMocks
            }
        }

        Context "Mock first Get returns nothing for Set" {
            
            Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Get-SCLibraryServer {
                
                Write-Verbose "Mock Get-SCLibraryServer $args.  MockCount: $MockCount"

                if($MockCount -eq 0)
                {
                    Write-Verbose "Mock no LibaryServer returned."

                    Write-Error -Exception "Mock Error LibraryServer not associated" -ErrorId 402
                }
                else
                {
                    Write-Verbose "Mock LibraryServer returned."

                    @{  ComputerName = $mockServerName; 
                        Description = $mockDescription 
                        HostGroupId = $mockHostGroupId
                        LibraryServerManagementCredential = $mockManagementCredentialName }
                }

                $Global:MockCount++
            }

            BeforeEach {
                
                $Global:MockCount = 0
            }

            AfterEach {

                $Global:MockCount  = 0
            }
            
            It "Set-TargetResource Add LibraryServer" {

                Set-TargetResource -ServerName $mockServerName `
                                -EnableUnencryptedFileTransfer $false `
                                -ManagementCredentialName $mockManagementCredentialName `
                                -HostGroupName $mockHostGroupName `
                                -Description $mockDescription `
                                -Verbose

                Assert-VerifiableMocks
            }
        }
   
        Context "Mock second Get returns nothing for Delete" {
            
              Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Get-SCLibraryServer {
                
                Write-Verbose "Mock Get-SCLibraryServer $args.  MockCount: $MockCount"

                if($MockCount -eq 0)
                {
                    Write-Verbose "Mock LibraryServer returned."

                    @{ ComputerName = $mockServerName 
                        Description = $mockDescription
                        HostGroupId = $mockHostGroupId
                        LibraryServerManagementCredential = $mockManagementCredentialName }
                }
                else
                {
                    Write-Verbose "Mock no LibaryServer returned."

                    Write-Error -Exception "Mock Error LibraryServer not associated" -ErrorId 402
                }

                $Global:MockCount++
            }

            BeforeEach {

                $Global:MockCount  = 0
            }

            AfterEach {

                $Global:MockCount  = 0
            }

            It "Set-TargetResource Absent" {

                Set-TargetResource -Ensure 'Absent' `
                    -ServerName $mockServerName `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -Verbose
                
                Assert-VerifiableMocks
            }
        }

        Context "Mock Set with different values" {
            
            Mock -ModuleName MSFT_xSCVMMLibraryServer -CommandName Get-SCLibraryServer {

                Write-Verbose "Mock Get-SCLibraryServer $args."
                Write-Verbose "Mock LibraryServer returned."

                @{ ComputerName = $mockServerName 
                    Description = $mockDescription
                    HostGroupId = ''
                    LibraryServerManagementCredential = $mockManagementCredentialName }
            }

            It "Set-TargetResource No VMHost" {

                Set-TargetResource -ServerName $mockServerName `
                    -EnableUnencryptedFileTransfer $false `
                    -ManagementCredentialName $mockManagementCredentialName `
                    -Description $mockDescription `
                    -Verbose

                Assert-VerifiableMocks
            }
        }
    }
}

Get-Module -Name VirtualMachineManager | Remove-Module
Get-Module -Name MSFT_xSCVMMLibraryServer | Remove-Module