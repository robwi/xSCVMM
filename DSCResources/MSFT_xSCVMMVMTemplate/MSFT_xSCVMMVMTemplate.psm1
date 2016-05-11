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
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $VHDName,
        
        [parameter(Mandatory = $true)]
        [System.UInt16]
        $MemorySizeInMB,
        
        [parameter(Mandatory = $true)]
        [System.Boolean]
        $IsHighlyAvailable,

        [parameter(Mandatory = $true)]
        [System.UInt16]
        $CPUCount,

        [System.String]
        $VMNetworkName = "Management",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $vmmConnection = Get-VMMServerConnection
    
    $returnValue = @{
        Ensure = "Absent"
        Name = $Name
        VHDName = $VHDName
        MemorySizeInMB = $MemorySizeInMB
        IsHighlyAvailable = $IsHighlyAvailable
        CPUCount = $CPUCount
        VMNetworkName = $VMNetworkName        
    }
    
    $template = Get-SCVMTemplate -Name $Name
    if($template)
    {
        $disk = Get-SCVirtualHardDisk -VMTemplate $template
        $vmnName = $template.VirtualNetworkAdapters[0].VMNetwork.Name
        $returnValue = @{
            Ensure = "Present"
            Name = $template.Name
            VHDName = $template.VirtualHardDisks[0].name
            MemorySizeInMB = $template.Memory
            IsHighlyAvailable = $template.IsHighlyAvailable
            CPUCount = $template.CPUCount
            VMNetworkName = $template.VirtualNetworkAdapters[0].VMNetwork.Name        
        }
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

        [parameter(Mandatory = $true)]
        [System.String]
        $VHDName,
        
        [parameter(Mandatory = $true)]
        [System.UInt16]
        $MemorySizeInMB,
        
        [parameter(Mandatory = $true)]
        [System.Boolean]
        $IsHighlyAvailable,

        [parameter(Mandatory = $true)]
        [System.UInt16]
        $CPUCount,

        [System.String]
        $VMNetworkName = "Management",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $vmmConnection = Get-VMMServerConnection

    Write-Verbose "Get Template by Name $Name if it already exists." -Verbose    
    $template = Get-SCVMTemplate -Name $Name    

    switch($Ensure)
    {
        "Present"
        {
            if($template)
            {
			    Write-Verbose "Remove already existing Template $Name." -Verbose
                $temp = Remove-SCVMTemplate -VMTemplate $template -ErrorAction Stop
            }    
             
            try
            {
			    Write-Verbose "Get OS object for R2 Datacenter." -Verbose
                $os = Get-SCOperatingSystem | where Name -eq 'Windows Server 2012 R2 Datacenter'
                Write-Verbose "Get VHD object $VHDName" -Verbose
                $vhd = Get-SCVirtualHardDisk -Name $VHDName -ErrorAction SilentlyContinue
		        if(!$vhd)
                {
                    Write-Verbose "Refresh Library to check if $VHDName already present on library share" -Verbose
                    $libShare = Get-SCLibraryShare -ErrorAction Stop
                    Write-Verbose "Refresh Library share" -Verbose
                    Read-SCLibraryShare -LibraryShare $libShare -ErrorAction Stop
                    Write-Verbose "Get VHDX object $VHDName after library refresh" -Verbose
                    $vhd = Get-SCVirtualHardDisk -Name $VHDName -ErrorAction Stop
                }
                Write-Verbose "Get VMNetwork object $VMNetworkName" -Verbose
		        $vmNetwork = Get-SCVMNetwork -Name $VMNetworkName -ErrorAction Stop
                 
                $guid = [guid]::NewGuid().Guid.ToString()
                Write-Verbose "Creating JobGroup $guid to create Template $Name" -Verbose 
                New-SCVirtualScsiAdapter -JobGroup $guid -AdapterID 7 -ShareVirtualScsiAdapter $false -ScsiControllerType DefaultTypeNoType 
                New-SCVirtualDVDDrive -JobGroup $guid -Bus 1 -LUN 0
                New-SCVirtualNetworkAdapter -JobGroup $guid -MACAddressType Static -MACAddress "00:00:00:00:00:00" -Synthetic -EnableVMNetworkOptimization $false -EnableMACAddressSpoofing $false -EnableGuestIPNetworkVirtualizationUpdates $false -IPv4AddressType Static -IPv6AddressType Dynamic -VMNetwork $vmNetwork 
                New-SCVirtualDVDDrive -JobGroup $guid -Bus 0 -LUN 1
                
				Write-Verbose "Executing Template creation JobGroup $guid to create Template $Name" -Verbose 
                $template = New-SCVMTemplate -Name $Name -HighlyAvailable $IsHighlyAvailable -OperatingSystem $os -VirtualHardDisk $vhd -MemoryMB $MemorySizeInMB -CPUCount $CPUCount -Generation 1 -JobGroup $guid -ErrorAction Stop
            }
            catch
            {
                if ($error[0]) {Write-Verbose $error[0].Exception}
                Write-Verbose -Message "Template $Name creation failed."
            }			
        }
        
        "Absent"
        {
            if($template)
            { 
                $temp = Remove-SCVMTemplate -VMTemplate $template -ErrorAction Stop
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
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $VHDName,
        
        [parameter(Mandatory = $true)]
        [System.UInt16]
        $MemorySizeInMB,
        
        [parameter(Mandatory = $true)]
        [System.Boolean]
        $IsHighlyAvailable,

        [parameter(Mandatory = $true)]
        [System.UInt16]
        $CPUCount,

        [System.String]
        $VMNetworkName = "Management",

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )   
    
    $returnValues = Get-TargetResource @PSBoundParameters

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
    
    if($result -eq $true -and $Ensure -eq "Present")
    {

        $actualValue = @{
            Ensure = "Present"
            Name = $Name
            VHDName = $VHDName
            MemorySizeInMB = $MemorySizeInMB
            IsHighlyAvailable = $IsHighlyAvailable
            CPUCount = $CPUCount
            VMNetworkName = $VMNetworkName        
        }
    
        if(!(Compare-ObjectAssert -ExpectedArray $actualValue.Values `
                                 -ActualArray $returnValues.Values `
                                 -MessageName "VMTemplateProperties"))
        {
            $result = $false
        }
    }

    $result
}


Export-ModuleMember -Function *-TargetResource

