# DSC resource to update a VMM file.

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
		[parameter(Mandatory = $true)]
		[System.String]
        $Path,

		[parameter(Mandatory = $true)]
		[System.String]
        $File,

		[parameter(Mandatory = $true)]
		[System.String]
        $Version
	)
   
    $FilePath = Join-Path -Path $Path -ChildPath $File
    if(Test-Path -Path $FilePath)
    {
        $Version = (Get-Item -Path $FilePath).VersionInfo.FileVersion
    }
    
	$returnValue = @{
        Path = $Path
        File = $File
        Version = $Version
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source\Updates",

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[parameter(Mandatory = $true)]
		[System.String]
        $Path,

		[parameter(Mandatory = $true)]
		[System.String]
        $File,

		[parameter(Mandatory = $true)]
		[System.String]
        $Version,

		[System.String]
        $Service
	)

    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
        $TempFolder = [IO.Path]::GetTempPath()
        & robocopy.exe (Join-Path -Path $SourcePath -ChildPath $SourceFolder) (Join-Path -Path $TempFolder -ChildPath $SourceFolder) /e
        $SourcePath = $TempFolder
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
    }
    
    $SourceFile = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath $File
    
    if(Test-Path -Path $SourceFile)
    {
        if($PSBoundParameters.ContainsKey('Service') -and ((Get-Service -Name $Service -ErrorAction SilentlyContinue).Status -eq 'Running'))
        {
            $StartService = $true
            Write-Verbose "Stopping service $Service"
            Stop-Service -Name $Service
            Start-Sleep 10
        }
        else
        {
            $StartService = $false
        }

        $Attempt = 1
        $Success = $false
        while(!$Success -and ($Attempt -le 10))
        {
            Write-Verbose "Copying $SourceFile to $Path, attempt $Attempt"
            try
            {
                Copy-Item -Path $SourceFile -Destination $Path
            }
            catch
            {
                Write-Verbose "Failed copying $SourceFile to $Path"
            }
            if(Test-TargetResource @PSBoundParameters)
            {
                $Success = $true
            }
            else
            {
                Write-Verbose "Failed copying $SourceFile to $Path, waiting 10 seconds"
                Start-Sleep 10
            }
            $Attempt++
        }

        if($StartService)
        {
            Write-Verbose "Starting service $Service"
            Start-Service -Name $Service
        }
    }
    else
    {
        Write-Verbose "$SourceFile does not exist"
    }

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
		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source\Updates",

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[parameter(Mandatory = $true)]
		[System.String]
        $Path,

		[parameter(Mandatory = $true)]
		[System.String]
        $File,

		[parameter(Mandatory = $true)]
		[System.String]
        $Version,

		[System.String]
        $Service
	)

	$result = ((Get-TargetResource -Path $Path -File $File -Version $Version).Version -eq $Version)
	
	$result
}


Export-ModuleMember -Function *-TargetResource