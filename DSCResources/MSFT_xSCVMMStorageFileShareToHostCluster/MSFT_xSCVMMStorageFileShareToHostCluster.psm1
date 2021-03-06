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
		$FileShareName,

		[parameter(Mandatory = $true)]
		[System.String]
		$FileServerName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName
	)

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    $vmmServerName = $env:COMPUTERNAME
    $vmmConnection = Get-VMMServerConnection -ServerName $vmmServerName

    $fileServer = Get-SCStorageFileServer -Name $FileServerName -VMMServer $vmmConnection -ErrorAction Stop                                                                                      
    if (!($fileServer))
    {
        Write-Verbose "Error occured in $functionName."
        throw New-TerminatingError -ErrorType StorageFileServerNotFound -FormatArgs @($fileServer) -ErrorCategory ObjectNotFound
    }

    $fileShare = $fileServer.StorageFileShares | Where-Object {$_.Name -eq $FileShareName}
    if (!($fileShare))
    {
        Write-Verbose "Error occured in $functionName."

        throw New-TerminatingError -ErrorType StorageFileShareNotFound -FormatArgs @($FileShareName, $FileServerName) -ErrorCategory ObjectNotFound
    }

    $hostCluster = Get-SCVMHostCluster -Name $HostClusterName -VMMServer $vmmConnection -ErrorAction Stop
    if (!($hostCluster))
    {
        Write-Verbose "Error occured in $functionName."

        throw New-TerminatingError -ErrorType HostClusterNotFound -FormatArgs @($HostClusterName) -ErrorCategory ObjectNotFound
    }

    # If the share is registered to first node then it's registered to all the nodes of the cluster (highly available shared storage).
    $share = Compare-Object $fileShare $hostCluster.Nodes[0].RegisteredStorageFileShares -IncludeEqual | Where-Object {$_.SideIndicator -eq '=='}
    if( $share -ne $null)
    {
        Write-Verbose -Message "$functionName $FileShareName is already registered to $HostClusterName."
        $Ensure = "Present"
    }
    else
    {
        $Ensure = "Absent"
    }

	$returnValue = @{
		StorageFileShareName = $fileShare.ShareName
		FileServerName = $FileServerName.Name
        Ensure = $Ensure
		HostClusterName = $hostCluster.Name
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
		$FileShareName,

		[parameter(Mandatory = $true)]
		[System.String]
		$FileServerName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,
        
        [ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present"
	)

    ValidateOrApply-Resource @PSBoundParameters -Apply
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$FileShareName,

		[parameter(Mandatory = $true)]
		[System.String]
		$FileServerName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,
        
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
		[System.String]
		$FileShareName,

		[parameter(Mandatory = $true)]
		[System.String]
		$FileServerName,

		[parameter(Mandatory = $true)]
		[System.String]
		$HostClusterName,
        
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

        $resourceProperties = Get-TargetResource -FileShareName $FileShareName -FileServerName $FileServerName -HostClusterName $HostClusterName
        if ($Ensure -eq "Present")
        {
            if ($resourceProperties['Ensure'] -eq "Absent")
            {
                if ($Apply) 
                {
                    $fileServer = Get-SCStorageFileServer -Name $FileServerName -VMMServer $vmmConnection -ErrorAction Stop                                                                                      
                    $fileShare = $fileServer.StorageFileShares | Where-Object {$_.Name -eq $FileShareName}

                    $hostCluster = Get-SCVMHostCluster -Name $HostClusterName -VMMServer $vmmConnection -ErrorAction Stop

                    Write-Verbose -Message "$functionName Working on share: $($fileShare.SharePath)." 
                    $shareWasRegisteredNow = $false                   
                    try
                    {
                        Register-SCStorageFileShare -StorageFileShare $fileShare -VMHostCluster $hostCluster -ErrorAction Stop
                        $shareWasRegisteredNow = $true
                        Write-Verbose -Message "$functionName Registered $fileShare to $hostCluster"
                    }
                    catch [Exception]
                    {
                        if (!($_.ErrorDetails.Message.Contains("26194"))) # Suppressing share already associated error 
                        {
                            throw $_
                        }
                        else
                        {
                            $shareWasRegisteredNow = $false
                            Write-Verbose -Message "$functionName Share $fileShare already registered." 
                        }
                    }

                    # If we registered the share then assinging the base disk path on each node of the cluster
                    if($shareWasRegisteredNow -eq $true)
                    {
                        # There could be a delay in propagation of share permissions hence adding a sleep for the permissions to be effective.
                        Write-Verbose -Message "$functionName There could be delay in propagation of share permissions hence sleeping for 10 seconds, for the permissions to be effective." -Verbose
                        Start-Sleep -Seconds 10
                        foreach ($clusterNode in $hostCluster.Nodes)
                        {
                            [string]$baseDiskPaths = "";
                            foreach ($path in $clusterNode.BaseDiskPaths)
                            {
                                $baseDiskPaths+=$path
                                $baseDiskPaths+="|"
                            }
                            $baseDiskPaths+=$fileShare.SharePath
                            Write-Verbose -Message "$functionName Setting BaseDiskPaths for '$clusterNode' as '$baseDiskPaths'."
                            Set-SCVMHost -VMHost $clusterNode -BaseDiskPaths $baseDiskPaths
                        }
                    }
                }
                else
                {
                    return $false
                }
            }
            else
            {
                if (!($Apply))
                {
                    return $true
                } 
            }
        }
        elseif ($Ensure -eq "Absent")
        {
            Write-Verbose "Error occured in $functionName."

            throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
        }
        else
        { 
            Write-Verbose "Error occured in $functionName."
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

