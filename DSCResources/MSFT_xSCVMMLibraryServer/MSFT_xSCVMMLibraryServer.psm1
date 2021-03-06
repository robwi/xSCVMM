$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
        [String]
        $ServerName,

        [Bool] 
        $EnableUnencryptedFileTransfer = $true,

        [String]
        $ManagementCredentialName,

        [String]
        $HostGroupName,

        [String]
        $Description
	)
    
    $vmmConnection = Get-VMMServerConnection

    $libraryServer = Get-SCLibraryServer -ComputerName $ServerName `
                                        -ErrorAction 'SilentlyContinue' `
                                        -VMMServer $vmmConnection `
                                        -ErrorVariable 'LibraryServerError'

    # Get-SCLibrary Server writes error if not found
    if($LibraryServerError)
    {
        # 402 = LibraryServer not associated
        if(!$libraryServerError[0].FullyQualifiedErrorId -eq 402)
        {
            throw $libraryServerError[0]
        }
    }
  
    if(!$libraryServer.HostGroupId)
    {
        $actualHostGroupName = 'All Hosts'
    }
    else
    {
        $actualHostGroupName = (Get-SCVMHostGroup -ID $libraryServer.HostGroupId -VMMServer $vmmConnection).Name
    }

    if($libraryServer)
    {
        $returnValue = @{
            Ensure = "Present"
            Description = $libraryServer.Description
            ServerName = $libraryServer.ComputerName
            ManagementCredentialName = $libraryServer.LibraryServerManagementCredential.Name
            HostGroupName = $actualHostGroupName
            EnableUnencryptedFileTransfer = $libraryServer.AllowUnencryptedTransfers
        }
	}
    else
    {
        $returnValue = @{
            Ensure = "Absent"
            Description = $null
            ServerName = $null
            ManagementCredentialName = $null
            HostGroupName = $null
        }
    }

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
        [String]
        $ServerName,

        [Bool] 
        $EnableUnencryptedFileTransfer = $true,

        [String]
        $ManagementCredentialName,

        [String]
        $HostGroupName,

        [String]
        $Description
	)
    
    $vmmConnection = Get-VMMServerConnection
        
    $libraryServerParams = @{}

    $runAsAccount = Get-SCRunAsAccount -Name $ManagementCredentialName -VMMServer $vmmConnection -ErrorAction Stop

    if(!$runAsAccount)
    {
        throw New-TerminatingError -ErrorType RunAsAccountNotFound -FormatArgs @($ManagementCredentialName) -ErrorCategory ObjectNotFound
    }

    switch($Ensure)
    {
        "Present"
        {
            if($HostGroupName)
            {
                $hostGroup = Get-SCVMHostGroup -Name $Name -VMMServer $vmmConnection -ErrorAction Stop

                if(!$hostGroup)
                {
                    throw New-TerminatingError -ErrorType HostGroupNotFound -FormatArgs @($hostGroup) -ErrorCategory ObjectNotFound
                }

                $libraryServerParams['VMHostGroup'] = $hostGroup
            }

            if($Description)
            {
                $libraryServerParams['Description'] = $Description
            }

            $libraryServerParams['EnableUnencryptedFileTransfer'] = $EnableUnencryptedFileTransfer

            $libraryServer = Get-SCLibraryServer -ComputerName $ServerName -VMMServer $vmmConnection -ErrorAction 'SilentlyContinue'

            if($libraryServer)
            {
                $libraryServerParams['LibraryServer'] = $libraryServer
                $libraryServerParams['LibraryServerManagementCredential'] = $runAsAccount
 
                Write-Verbose "Setting Library Server with parameters: $($libraryServerParams | Out-String)"

                $null = Set-SCLibraryServer @libraryServerParams -ErrorAction Stop
	        }
            else
            {
                $libraryServerParams['ComputerName'] = $ServerName
                $libraryServerParams['Credential'] = $runAsAccount
 
                Write-Verbose "Adding Library Server with parameters: $($libraryServerParams | Out-String)"

                $null = Add-SCLibraryServer @libraryServerParams -VMMServer $vmmConnection -ErrorAction Stop 
            }
        }
        "Absent"
        {
            $libraryServer = Get-SCLibraryServer -ComputerName $ServerName -VMMServer $vmmConnection -ErrorAction 'SilentlyContinue'

            if($libraryServer)
            {
                $libraryServerParams['LibraryServer'] = $libraryServer
                $libraryServerParams['Credential'] = $runAsAccount

                Write-Verbose "Removing Library Server with parameters: $($libraryServerParams | Out-String)"

                Remove-SCLibraryServer @libraryServerParams -ErrorAction Stop 
	        }
            else
            {
                Write-Warning "Library Server expected to exist for removal but does not exist."
            }
        }
    }

    # For now call Test at the end of Set
    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType TestFailedAfterSet -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
        [String]
        $ServerName,

        [Bool] 
        $EnableUnencryptedFileTransfer = $true,

        [String]
        $ManagementCredentialName,

        [String]
        $HostGroupName,
       
        [String]
        $Description
	)
    
    $result = $true

    $libraryServerResult = Get-TargetResource @PSBoundParameters

    if($libraryServerResult.Ensure -ne $Ensure)
    {
        Write-Verbose "Expected Ensure: ""$Ensure"" Actual: ""$($libraryServerResult.Ensure)""." 

        $result = $false
    }

    if($libraryServerResult.Ensure -eq "Absent")
    {
        return $true
    }

    if($PSBoundParameters.ContainsKey('EnableUnencryptedFileTransfer') -and ($libraryServerResult.EnableUnencryptedFileTransfer -ne $EnableUnencryptedFileTransfer))
    {
        Write-Verbose "Expected EnableUnencryptedFileTransfer: ""$EnableUnencryptedFileTransfer"" Actual: ""$($libraryServerResult.EnableUnencryptedFileTransfer)""." 

        $result = $false
    }

    if($PSBoundParameters.ContainsKey('Description') -and ($libraryServerResult.Description -ne $Description))
    {
        Write-Verbose "Expected Description: ""$Description"" Actual: ""$($libraryServerResult.Description)""." 

        $result = $false
    }

    if($PSBoundParameters.ContainsKey('ManagementCredentialName') -and ($libraryServerResult.ManagementCredentialName -ne $ManagementCredentialName))
    {
        Write-Verbose "Expected ManagementCredentialName: ""$ManagementCredentialName"" Actual: ""$($libraryServerResult.ManagementCredentialName)""." 

        $result = $false
    }

    if($PSBoundParameters.ContainsKey('HostGroupName'))
    {
        if(!$HostGroupName)
        {
            $expectedHostGroupName = 'All Hosts'
        }
        else
        {
            $expectedHostGroupName = $HostGroupName
        }

        if($libraryServerResult.HostGroupName -ne $expectedHostGroupName)
        {
            Write-Verbose "Expected HostGroupName: ""$expectedHostGroupName"" Actual: ""$($libraryServerResult.HostGroupName)""." 

            $result = $false
        }
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource
