<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    System Center Custom Properties DSC resource.

.DESCRIPTION
    Creates, Gets, and Tests System Center Custom Properties.
#>
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
        
        [Parameter(Mandatory=$true)]
        [String]
        $Name,

        [String]
        $Description,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String[]]
        $Members
	)
    
    $vmmConnection = Get-VMMServerConnection

    $customProperty = Get-SCCustomProperty -Name $Name -VMMServer $vmmConnection

    if($customProperty)
    {
        $returnValue = @{
            Ensure = "Present"
            Name = $Name
            Description = $customProperty.Description 
            Members = $customProperty.Members }
	}
    else
    {
        $returnValue = @{
            Ensure = "Absent"
            Name = $Name
            Description = $null
            Members = $null }
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
        
        [Parameter(Mandatory=$true)]
        [String]
        $Name,

        [String]
        $Description,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String[]]
        $Members
	)
    
    $vmmConnection = Get-VMMServerConnection

    $customProperty = Get-SCCustomProperty -Name $Name -VMMServer $vmmConnection -ErrorAction Stop

    switch($Ensure)
    {
        "Present"
        {
            $customPropertyArgs = @{}

            if($Description)
            {
                $customPropertyArgs["Description"] = $Description
            }
                        
            if(!$customProperty)
            {
                Write-Verbose "Creating Custom Property ""$Name""."

                if($Members)
                {
                    $null = New-SCCustomProperty -Name $Name `
                                                -AddMember $Members `
                                                @customPropertyArgs `
                                                -VMMServer $vmmConnection `
                                                -ErrorAction Stop
                }
            }
            else
            {
                Write-Verbose "Looking for new member types."

                $Members | ForEach-Object `
                            {
                                if($_ -notin $customProperty.Members)
                                {
                                    Write-Verbose "Found New Member Type: $_"
                                    $newMembers += $_
                                }
                            }

                Write-Verbose "Setting Custom Property ""$Name""."

                if($newMembers)
                {
                    $customPropertyArgs["AddMember"] = $newMembers
                }

                $null = Set-SCCustomProperty -CustomProperty $customProperty `
                                                @customPropertyArgs `
                                                -VMMServer $vmmConnection `
                                                -ErrorAction Stop
            }
        }
        "Absent"
        {
            if(!$customProperty)
            {
                Write-Warning "Custom Property ""$Name"" expected to be removed does not exist." 
            }

            Write-Verbose "Removing Custom Property ""$Name""."

            $null = Remove-SCCustomProperty -CustomProperty $customProperty -ErrorAction Stop
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
        
        [Parameter(Mandatory=$true)]
        [String]
        $Name,

        [String]
        $Description,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String[]]
        $Members
	)

    $retVal = Get-TargetResource @PSBoundParameters

    if($retVal.Ensure -ne $Ensure)
    {
        Write-Verbose "Expected Ensure: ""$Ensure"" Actual: ""$($retVal.Ensure)""." 

        return $false
    }

    if($retVal.Ensure -eq "Absent")
    {
        return $true
    }

    $result = $true

    if(!(Compare-ObjectAssert -ExpectedArray $Members `
                            -ActualArray $retVal.Members `
                            -MessageName "Members"))
    {
        Write-Verbose "Custom Properties for ""$Name"" do not match expected values."

        $result = $false
    }

    if($Description)
    {
        if($Description -ne $retVal.Description)
        {
            Write-Verbose "Expected Description: ""$Description"" Actual: ""$($retVal.Description)""."

            $result = $false
        }
    }

	$result
}

Export-ModuleMember -Function *-TargetResource
