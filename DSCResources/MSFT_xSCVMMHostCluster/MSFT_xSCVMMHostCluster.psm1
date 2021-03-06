$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-WindowsClusterInfoLocally
{
    [CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
    param()

    try
    {
        if(!(Get-Module -Name 'FailoverClusters'))
        {
            Write-Verbose "Importing FailoverClusters Module"
           
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = "SilentlyContinue"
            $null = Import-Module FailoverClusters -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
        }
    }
    catch
    {
        Write-Verbose "Problem with importing FailoverClusters on ""$env:ComputerName"".  Ensure Windows Failover Clustering is installed correctly."

        throw $_
    }

    try 
    {
        $clusterNodeList = Get-ClusterNode -ErrorAction Stop

        $clusterName = (Get-Cluster -Name localhost -ErrorAction Stop).Name
    }
    catch
    {
        Write-Verbose "Error getting cluster information on: ""$env:ComputerName""."

        throw $_
    }

    $returnValue = @{
            ClusterNodeNames = $clusterNodeList.Name
            ClusterName = $clusterName}

	$returnValue  
}

function Get-ConnectionAndClusterOnVMMServer
{
    [CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
    param(
        [String] 
        $ClusterName,

        [String] 
        $VerbosePreferenceEnum
    )

    $VerbosePreference = $VerbosePreferenceEnum

    try
    {
        if(!(Get-Module -Name 'VirtualMachineManager'))
        {
            Write-Verbose "Importing VirtualMachineManager Module"
           
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = "SilentlyContinue"
            $null = Import-Module VirtualMachineManager -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
        }

        Write-Verbose "Getting SCVMMServer for $env:ComputerName."

        $vmmConnection = Get-SCVMMServer -ComputerName $env:ComputerName -ErrorAction Stop

        Write-Verbose "Getting SCVMHostCluster for cluster ""$ClusterName""."

        $vmmCluster = Get-SCVMHostCluster -VMMServer $vmmConnection -ErrorAction Stop | Where { $_.ClusterName -eq $ClusterName }
    }
    catch
    {
        Write-Verbose "Problem with VMM on ""$env:ComputerName"".  Ensure VMM is installed correctly."

        throw $_
    }

    # Powershell Serialization bug work around
    # https://microsoft.visualstudio.com/DefaultCollection/WSSC/_workitems/edit/2918617?fullScreen=false 
    if($vmmCluster -eq $null)
    {
        $vmmCluster = $null
    }

    $NodeValues = @()
    
    $vmmCluster.Nodes | ForEach-Object { $NodeValues += $_ }

    $returnValue = @{
            VMMCluster = $vmmCluster
            VMMConnection = $vmmConnection
            NodeValues = $NodeValues }

	$returnValue  
}

function Set-HostClusterOnVMMServer
{
    [CmdletBinding()]
    param(
        [ValidateSet("Present","Absent")]
		[String]
        $Ensure = "Present",

        [String] 
        $HostGroupName,

        [String] 
        $ManagementCredentialName,

        [Byte] 
        $ClusterReserve,

        [String] 
        $ClusterName,

        [String[]]
        $WindowsClusterNodeNames,

        [String] 
        $GetConnectionAndClusterOnVMMServer,

        [String] 
        $VerbosePreferenceEnum
    )

    $VerbosePreference = $VerbosePreferenceEnum

    $script = [ScriptBlock]::Create($GetConnectionAndClusterOnVMMServer)
    $retVal = $script.Invoke($ClusterName, $VerbosePreferenceEnum)

    $vmmConnection = $retVal.VMMConnection
    $vmmCluster = $retVal.VMMCluster

    Write-Verbose -Message "Getting RunAs Account: ""$ManagementCredentialName""."

    $runAsAccount = Get-SCRunAsAccount -Name $ManagementCredentialName -VMMServer $vmmConnection -ErrorAction Stop

    if(!$runAsAccount)
    {
        # Because this is called remotely we will localize and throw from the client.
        throw "RunAsAccountNotFound"
    }

    switch($Ensure)
    {
        "Present"
        {
            if($vmmCluster) 
            {
                Write-Verbose -Message "Looking for nodes in the cluster that are not part of VMM."

                Write-Verbose -Message "Create VMM cluster node short names by removing domain information."

                $vmmShortNames = @()
                $vmmCluster.Nodes.Name | ForEach-Object { 

                                                $startIndex = $_.IndexOf('.')
                        
                                                if($startIndex -and ($startIndex -gt 0) -and ($startIndex -lt $_.Length))
                                                {
                                                    $vmmShortNames += $_.Remove($startIndex)
                                                }
                                                else
                                                {
                                                    Write-Verbose "Computer $_ does not have a domain name."

                                                    $vmmShortNames += $_
                                                }
                                            }

                Write-Verbose "Windows Cluster Nodes: $WindowsClusterNodeNames"
                Write-Verbose "VMM Cluster Nodes: $vmmShortNames"

                $WindowsClusterNodeNames | ForEach-Object { 
                    
                                                if( $_ -notin $vmmShortNames )
                                                {
                                                    Write-Verbose "Node ""$_"" was not yet found in VMM. Attempting to add to host cluster." 

                                                    $null = Add-SCVMHost -ComputerName $_ -Credential $runAsAccount `
                                                                    -VMHostCluster $vmmCluster -VMMServer $vmmConnection -ErrorAction Stop
                                                }
                                            }

                Write-Verbose -Message "Looking for Pending nodes to add to host cluster."

                $vmmCluster.Nodes | ForEach-Object {

                    if($_.OverallStateString -eq 'Pending')
                    {
                        Write-Verbose "Node ""$($_.Name)"" was found in pending state.  Adding to host cluster." 

                        $null = Add-SCVMHost -ComputerName $_.Name -Credential $runAsAccount `
                                            -VMHostCluster $vmmCluster -VMMServer $vmmConnection -ErrorAction Stop
                    }
                }
            }
            else 
            {
                # Add existing cluster to VMM
                if($HostGroupName)
                {
                    Write-Verbose -Message "Getting VMHostGroup: ""$HostGroupName""."

                    $HostGroup = Get-SCVMHostGroup -Name $HostGroupName -VMMServer $vmmConnection -ErrorAction Stop

                    if(!$HostGroup)
                    {
                        # Because this is called remotely we will localize and throw from the client.
                        throw "HostGroupNotFound"   
                    }
                }
                else
                {
                    Write-Verbose -Message "Getting VMHostGroup: ""All Hosts""."

                    $HostGroup = Get-SCVMHostGroup -Name 'All Hosts' -VMMServer $VMMConnection -ErrorAction Stop 
                }
   
                Write-Verbose -Message "Creating VMM cluster: ""$ClusterName"" with reserve: ""$ClusterReserve"" HostGroup: ""$($hostgroup.Name)"" and RunAs: ""$($runAsAccount.UserName)""."
                    
                $null = Add-SCVMHostCluster -Name $ClusterName -VMHostGroup $hostGroup -ClusterReserve $ClusterReserve -VMMServer $vmmConnection `
                        -Credential $runAsAccount -ErrorAction Stop
     
            }
        }
        "Absent"
        {
            if($vmmCluster)
            {
                try
                {
                    Write-Verbose "Removing VMM cluster: $($vmmCluster.ClusterName) with Credential: ""$($runAsAccount.UserName)""." 

                    $null = Remove-SCVMHostCluster -VMHostCluster $vmmCluster -Credential $runAsAccount -ErrorAction Stop
                }
                catch
                {
                    Write-Verbose "Failed to remove cluster: ""$($vmmCluster.ClusterName)""."

                    throw $_
                }
            }
            else
            {
                Write-Warning "VMM cluster expected to not exist and is not found. Set should not have been called in this case." 
            }
        }
    }
}

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Present","Absent")]
		[String] 
        $Ensure = "Present",

        [Parameter(Mandatory=$false)]
        [string] 
        $HostGroupName,

        [Parameter(Mandatory=$true)]
        [String] 
        $ManagementCredentialName,

        [Parameter(Mandatory=$false)]
        [Byte] 
        $ClusterReserve = 1,

        [Parameter(Mandatory = $true)]
		[String] 
        $VMMServerName
	)

    $retVal = Get-WindowsClusterInfoLocally -ErrorAction Stop
    $clusterName = $retVal.ClusterName

    $retVal = Invoke-Command -ComputerName $VMMServerName `
                        -ScriptBlock ${Function:Get-ConnectionAndClusterOnVMMServer} -ArgumentList @($clusterName, $VerbosePreference) `
                        -ErrorAction Stop
    
    $vmmCluster = $retVal.VMMCluster

    $hasPendingNodes = $false

    # $VmmCluster.Nodes is serialized to flat so we have to use $retVal.NodeValues
    $retVal.NodeValues | ForEach-Object {

        if($_.OverallStateString -eq 'Pending')
        {
            Write-Verbose "Node ""$_"" is in Pending state." 

            $hasPendingNodes = $true
        }      
    }

    if($retVal.NodeValues)
    {
        $nodeNames = $retVal.NodeValues.Name
    }

    if($vmmCluster)
    {
        $returnValue = @{
            Ensure = "Present"
            ClusterName = $vmmCluster.ClusterName
            HostGroupName = $vmmCluster.HostGroup
            ClusterReserve = $vmmCluster.ClusterReserve
            NodeNames = $nodeNames 
            HasPendingNodes = $hasPendingNodes } 
	}
    else
    {
        $returnValue = @{
            Ensure = "Absent"
            ClusterName = $null 
            HostGroupName = $null 
            ClusterReserve = $null 
            NodeNames = $null
            HasPendingNodes = $null }
    }

	return $returnValue  
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Present","Absent")]
		[String] 
        $Ensure = "Present",

        [Parameter(Mandatory=$false)]
        [string] 
        $HostGroupName,

        [Parameter(Mandatory=$true)]
        [String] 
        $ManagementCredentialName,

        [Parameter(Mandatory=$false)]
        [Byte] 
        $ClusterReserve = 1,

        [Parameter(Mandatory = $true)]
		[String] 
        $VMMServerName
	)
    
    $retVal = Get-WindowsClusterInfoLocally -ErrorAction Stop
    $windowsClusterNodeNames = $retVal.ClusterNodeNames
    $clusterName = $retVal.ClusterName

    try
    {
    Invoke-Command -ComputerName $VMMServerName `
                        -ScriptBlock ${Function:Set-HostClusterOnVMMServer} `
                        -ArgumentList @($Ensure, $HostGroupName, $ManagementCredentialName, $ClusterReserve, `
                                        $clusterName, $windowsClusterNodeNames, ${Function:Get-ConnectionAndClusterOnVMMServer}, `
                                        $VerbosePreference) `
                        -ErrorAction Stop
    }
    catch
    {
        $exception = $_.Exception

        switch($exception.Message)
        {
            "RunAsAccountNotFound" 
            {
                throw New-TerminatingError -ErrorType RunAsAccountNotFound -FormatArgs @($ManagementCredentialName) -ErrorCategory ObjectNotFound
            }

            "HostGroupNotFound"
            {
                throw New-TerminatingError -ErrorType HostGroupNotFound -FormatArgs @($HostGroupName) -ErrorCategory ObjectNotFound
            }

            default
            {
                throw $exception
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
        [Parameter(Mandatory=$true)]
        [ValidateSet("Present","Absent")]
		[String] 
        $Ensure = "Present",

        [Parameter(Mandatory=$false)]
        [String] 
        $HostGroupName,

        [Parameter(Mandatory=$true)]
        [String] 
        $ManagementCredentialName,

        [Parameter(Mandatory=$false)]
        [Byte] 
        $ClusterReserve = 1,

        [Parameter(Mandatory = $true)]
		[String] 
        $VMMServerName
	)

    $retVal = Get-WindowsClusterInfoLocally -ErrorAction Stop
    $clusterNodeNames = $retVal.ClusterNodeNames

    $retVal = Get-TargetResource @PSBoundParameters -ErrorAction Stop

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

    if(!$HostGroupName)
    {
        if($retVal.HostGroupName -ne "All Hosts")
        {
            Write-Verbose "Expected HostGroup: 'All Hosts' Actual: ""$($retVal.HostGroupName)""." 

            $result = $false
        }
    }
    elseif($HostGroupName -ne $retVal.HostGroupName)
    {
        Write-Verbose "Expected HostGroup: ""$HostGroupName"" Actual: ""$($retVal.HostGroupName)""."

        $result = $false
    }
    
    if($ClusterReserve -ne $retVal.ClusterReserve)
    {
        Write-Verbose "Expected ClusterReserve: ""$ClusterReserve"" Actual: ""$($retVal.ClusterReserve)""." 

        $result = $false
    }

    # VmmNodes contain the fully qualified name where cluster nodes do not.
    $vmmNodes = $retVal.NodeNames | % { $_.Remove($_.IndexOf('.')) }

    # Compare only the cluster nodes vs VMM incase a node was added outside the cluster
    if(!(Compare-ObjectAssert -ExpectedArray $clusterNodeNames `
                                -ActualArray $vmmNodes `
                                -MessageName "ClusterNodeNames" `
                                -CompareType 'Left'))
    {
        $result = $false
    }

    if($retVal.HasPendingNodes)
    {
        Write-Verbose "VMM Cluster: ""$($ret.ClusterName)"" nodes in Pending state."
        
        $result = $false
    }

	return $result
}


Export-ModuleMember -Function *-TargetResource