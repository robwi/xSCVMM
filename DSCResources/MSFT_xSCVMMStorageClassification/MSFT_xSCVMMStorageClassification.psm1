# NOTE: This resource requires WMF5 and PsDscRunAsCredential, 
# Runs on VMM Management Server.

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
		$Name
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    $vmmServerName = $env:COMPUTERNAME
    $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

    $storageClassification = Get-SCStorageClassification -Name $Name -VMMServer $vmmConnection;
    if (!($storageClassification))
    {
        Write-Verbose -Message "$functionName We didn't find a storage classification: $Name."
        $Ensure = 'Absent'
    }
    else
    {
        Write-Verbose -Message "$functionName Found storage classification $storageClassification."
        $Ensure = 'Present'
    }

	$returnValue = @{
		Name = $Name
        Ensure = $Ensure
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present"
	)

    ValidateOrApply-Resource @PSBoundParameters -Apply

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
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present"
	)

    $isDesiredState = ValidateOrApply-Resource @PSBoundParameters

    return $isDesiredState
}

# This is an internal function that is either used by Test or Set for the resource based on the Apply flag.
#
function ValidateOrApply-Resource 
{ 
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
		[System.String]
		$Name,

        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

        [Switch]$Apply
	) 
    
    $functionName = $($MyInvocation.MyCommand.Name) + ":"
  
    try
    {
        $vmmServerName = $env:COMPUTERNAME
        if ($Apply)
        {
            $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName 
        }

        $resourceProperties = Get-TargetResource -Name $Name
        if ($Ensure -eq "Present")
        {
            if ($resourceProperties['Ensure'] -eq "Absent")
            {
                if ($Apply) 
                {
                    Write-Verbose -Message "$wfName Creating new storage classification with name $Name."
                    $null = New-SCStorageClassification -Name $Name -Description "" -ErrorAction Stop
                }
                else
                {
                    Write-Verbose -Message "$functionName Storage Classification $Name does not exists."
                    return $false
                }
            }
            else
            {
                if (!($Apply)) 
                {
                    Write-Verbose -Message "$functionName Found storage Classification $Name. No need to do anything."
                    return $true
                }
            }
        }
        elseif ($Ensure -eq "Absent")
        {
            throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
        }
        else
        { 
            throw New-TerminatingError -ErrorType InvalidEnsureValue
        }
        
    }
    catch
    {
        Write-Verbose -Message "$functionName has failed! Message: $_ ."
        throw $_
    }
}

Export-ModuleMember -Function *-TargetResource

