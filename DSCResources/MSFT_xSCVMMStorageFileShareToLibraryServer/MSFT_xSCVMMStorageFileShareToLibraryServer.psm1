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
        $FileShareName,

        [Parameter(Mandatory = $true)]
        [String]
        $FileServerName,

        [Parameter(Mandatory = $true)]
        [String]
        $LibraryServerName
	)
    
    $vmmConnection = Get-VMMServerConnection

    $retVal = Get-ShareInformation -FileShareName $FileShareName `
                                    -FileServerName $FileServerName `
                                    -LibraryServerName $LibraryServerName `
                                    -ErrorAction Stop
    
    # Fileshare will contain library server if registration was successful
    if($retVal.FileShare.LibraryServer -eq $LibraryServerName)
    {
        $returnValue = @{
                            Ensure = 'Present'
                            FileShareName = $FileShareName
                            FileSharePath = $retVal.FileShare.SharePath
                            FileServerName = $FileServerName 
                            LibraryServerName = $LibraryServerName }
    }
    else
    {
        $returnValue = @{
                            Ensure = 'Absent'
                            FileShareName = $FileShareName
                            FileSharePath = $null
                            FileServerName = $FileServerName
                            LibraryServerName = $LibraryServerName }
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
        $FileShareName,

        [Parameter(Mandatory = $true)]
        [String]
        $FileServerName,

        [Parameter(Mandatory = $true)]
        [String]
        $LibraryServerName
	)

    $vmmConnection = Get-VMMServerConnection

    $retVal = Get-ShareInformation -FileShareName $FileShareName `
                                    -FileServerName $FileServerName `
                                    -LibraryServerName $LibraryServerName `
                                    -ErrorAction Stop

    switch($Ensure)
    {
        "Present"
        {
            Write-Verbose -Message "Registering $FileShareName to $LibraryServerName."

            $null = Register-SCStorageFileShare -LibraryServer $retVal.LibraryServer `
                                        -StorageFileShare $retVal.FileShare `
                                        -ErrorAction SilentlyContinue `
                                        -ErrorVariable registerFileShareError

            # Suppress certain errors
            if($registerFileShareError)
            {
                if($registerFileShareError.Count -gt 1)
                {
                    throw $registerFileShareError
                }

                # 26236 = share already associated error 
                if(!($registerFileShareError[0].FullyQualifiedErrorId -eq 26236))
                {
                    throw $registerFileShareError
                }
                else
                {
                    Write-Verbose -Message "File share: $FileShareName already registered to $LibraryServerName."
                }
            } 
        }
        "Absent"
        {
            $null = UnRegister-SCStorageFileShare -LibraryServer $retVal.LibraryServer `
                                                    -StorageFileShare $retVal.FileShare `
                                                    -ErrorAction SilentlyContinue `
                                                    -ErrorVariable registerFileShareError

            # Suppress certain errors
            if($registerFileShareError)
            {
                if($registerFileShareError.Count -gt 1)
                {
                    throw $registerFileShareError
                }

                # 26187 = share already un-associated error 
                if(!($registerFileShareError[0].FullyQualifiedErrorId -eq 26187))
                {
                    throw $registerFileShareError
                }
                else
                {
                    Write-Verbose -Message "File share: $FileShareName is already un-registered from $LibraryServerName."
                }
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
	[OutputType([Boolean])]
	param
	(
		[ValidateSet("Present","Absent")]
		[String]
		$Ensure = "Present",

        [Parameter(Mandatory = $true)]
        [String]
        $FileShareName,

        [Parameter(Mandatory = $true)]
        [String]
        $FileServerName,

        [Parameter(Mandatory = $true)]
        [String]
        $LibraryServerName
	)

    $retVal = Get-TargetResource @PSBoundParameters

    if($retVal.Ensure -ne $Ensure)
    {
        Write-Verbose "Expected Ensure: ""$Ensure"" Actual: ""$($retVal.Ensure)""." 

        return $false
    }
    else
    {
        return $true
    }
}

function Get-ShareInformation
{
	param
	(   
        [Parameter(Mandatory = $true)]
        [String]
        $FileShareName,

        [Parameter(Mandatory = $true)]
        [String]
        $FileServerName,

        [Parameter(Mandatory = $true)]
        [String]
        $LibraryServerName
	)

    $vmmConnection = Get-VMMServerConnection

    Write-Verbose -Message "Getting library server: $libraryServer."

    $libraryServer = Get-SCLibraryServer -ComputerName $LibraryServerName -VMMServer $vmmConnection -ErrorAction Stop

    if (!($libraryServer))
    {
        throw New-TerminatingError -ErrorType LibraryServerNotFound -FormatArgs @($LibraryServerName) -ErrorCategory ObjectNotFound
    }
            
    Write-Verbose -Message "Getting file Server; $FileServerName."

    $fileServer = Get-SCStorageFileServer -Name $FileServerName -VMMServer $vmmConnection -ErrorAction Stop

    if (!($fileServer))
    {
        throw New-TerminatingError -ErrorType StorageFileServerNotFound -FormatArgs @($FileServerName) -ErrorCategory ObjectNotFound
    }

    Write-Verbose -Message "Getting storage file share $FileShareName on $FileServerName."

    $fileShare = $fileServer.StorageFileShares | Where-Object { $_.Name -eq $FileShareName }

    if (!($fileShare))
    {
        throw New-TerminatingError -ErrorType StorageFileShareNotFound -FormatArgs @($FileShareName, $FileServerName) -ErrorCategory ObjectNotFound
    }

    $returnValue = @{ 
                        FileShare = $fileShare 
                        FileServer = $fileServer
                        LibraryServer =$libraryServer } 

    $returnValue
}
Export-ModuleMember -Function *-TargetResource