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
        [Parameter(Mandatory=$true)]
        [string] 
        $Name,

        [Parameter(Mandatory=$false)]
        [string] 
        $Description,

        [ValidateSet("Present","Absent")]
		[String] 
        $Ensure = "Present"
	)

    $vmmConnection = Get-VMMServerConnection

    $hostGroup = Get-SCVMHostGroup -Name $Name -VMMServer $vmmConnection -ErrorAction Stop

    if($hostGroup)
    {
        $returnValue = @{
            Ensure = "Present"
            Description = $hostGroup.Description
            Name = $hostGroup.Name
            Path = $hostGroup.Path}
	}
    else
    {
        $returnValue = @{
            Ensure = "Absent"
            Description = $null
            Name = $null
            Path = $null}
    }

	$returnValue 
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        [string] 
        $Name,

        [Parameter(Mandatory=$false)]
        [string] 
        $Description,

        [ValidateSet("Present","Absent")]
		[String] 
        $Ensure = "Present"
	)

    $vmmConnection = Get-VMMServerConnection

    switch($Ensure)
    {
        "Present"
        {
            Write-Verbose "Adding Host Group: ""$Name""." 

            if(!$Description)
            {
                $Description = ""
            }

            $null = New-SCVMHostGroup -Name $Name -Description $Description -VMMServer $vmmConnection -ErrorAction Stop
        }
        "Absent"
        {
            $hostGroup = Get-SCVMHostGroup -Name $Name -VMMServer $vmmConnection -ErrorAction Stop

            if($hostGroup)
            {      
                Write-Verbose "Removing Host Group: ""$Name""." 

                $null = Remove-SCVMHostGroup -VMHostGroup $hostGroup -ErrorAction Stop
            }
            else
            {
                Write-Warning "Host Group expected to not exist and is not found. Set should not have been called in this case." 
            }
        }
    }

    # Test at the end of Set Required
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
        [Parameter(Mandatory=$true)]
        [string] 
        $Name,

        [Parameter(Mandatory=$false)]
        [string] 
        $Description,

        [ValidateSet("Present","Absent")]
		[String] 
        $Ensure = "Present"
	)

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}

Export-ModuleMember -Function *-TargetResource