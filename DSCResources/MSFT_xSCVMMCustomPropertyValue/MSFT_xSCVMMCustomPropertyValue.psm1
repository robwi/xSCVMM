<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ##################################################>

 <#
.SYNOPSIS
    System Center Custom Property Value DSC resource.

.DESCRIPTION
    Sets, Gets, and Tests System Center Custom Property Values.
#>

$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\SCVMMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-PropertyObjects
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $PropertyName,

        [Parameter(Mandatory=$true)]
        [String]
        $ObjectName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String]
        $Member
    )

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

        Write-Verbose "Getting SCVMMServer for $env:COMPUTERNAME."

        $vmmConnection = Get-SCVMMServer -ComputerName $env:COMPUTERNAME -ErrorAction Stop
    }
    catch
    {
        Write-Verbose "Problem with VMM on ""$env:COMPUTERNAME"".  Ensure VMM is installed correctly."

        throw $_
    }
                            
    Write-Verbose "Getting Custom Property: ""$PropertyName""."

    $customProperty = Get-SCCustomProperty -Name $PropertyName -VMMServer $vmmConnection -ErrorAction Stop

    if(!$customProperty)
    {
        throw 'CustomPropertyNotFound2'
    }

    if($Member -notin $customProperty.Members)
    {
        throw 'CustomPropertyMemberNotFound'
    }
           
    Write-Verbose "Getting object: ""$ObjectName"" of member type: ""$Member""."

    switch($Member)
    {
        "Cloud"
        {
            $inputObject = Get-SCCloud -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "ComputerTier"
        {
            $service = Get-SCService -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
            $inputObject = Get-SCComputerTier -Service $service -VMMServer $vmmConnection -ErrorAction Stop
        }
        "HostCluster"
        {
            $inputObject = Get-SCVMHostCluster -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "ServiceInstance"
        {
            $inputObject = Get-SCService -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "ServiceTemplate"
        {
            $inputObject = Get-SCServiceTemplate -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "Template"
        {
            $inputObject = Get-SCVMTemplate -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "VM"
        {
            $inputObject = Get-SCVirtualMachine -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "VMHost"
        {
            $inputObject = Get-SCVMHost -ComputerName $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
        "VMHostGroup"
        {
            # Note: Multiple VMHostGroups with the same name under different parents - Not supported
            # In order to properly support this Name should be a Path and split with multiple calls.
            $inputObject = Get-SCVMHostGroup -Name $ObjectName -VMMServer $vmmConnection -ErrorAction Stop
        }
    }

    if(!$inputObject)
    {
        throw 'CustomPropertyObjectNotFound' 
    }

    if($inputObject.GetType().IsArray)
    {
        throw 'CustomPropertyObjectInvalidReturn'
    }

    return @{
                CustomProperty = $customProperty
                InputObject = $inputObject
            }
}

function Get-PropertyValue
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $GetPropertyObjects,

        [Parameter(Mandatory=$true)]
        [String]
        $PropertyName,

        [Parameter(Mandatory=$true)]
        [String]
        $ObjectName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String]
        $Member,

        [String] 
        $VerbosePreferenceEnum
    )

    $VerbosePreference = $VerbosePreferenceEnum
                   
    $script = [ScriptBlock]::Create($GetPropertyObjects)
    $retVal = $script.Invoke($PropertyName,$ObjectName,$Member)   

    $vmmConnection = Get-SCVMMServer -ComputerName $env:COMPUTERNAME

    Write-Verbose "Getting Custom Property Value of Property: ""$PropertyName"" on object: ""$ObjectName""."
    
    $propertyValueObject = Get-SCCustomPropertyValue -CustomProperty $retVal.CustomProperty -InputObject $retVal.InputObject `
                                                    -VmmServer $vmmConnection -ErrorAction Stop

    if($propertyValueObject)
    {
        $propertyValue = $propertyValueObject.Value
    }
    else
    {
        $propertyValue = $null
    }

    return $propertyValue
}

function Set-PropertyValue
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $GetPropertyObjects,

        [Parameter(Mandatory=$true)]
        [String]
        $PropertyName,

        [Parameter(Mandatory=$true)]
        [String]
        $ObjectName,

        [Parameter(Mandatory=$true)]
        [String]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String]
        $Member,

        [String] 
        $VerbosePreferenceEnum
    )

    $VerbosePreference = $VerbosePreferenceEnum

    $script = [ScriptBlock]::Create($GetPropertyObjects)
    $retVal = $script.Invoke($PropertyName,$ObjectName,$Member)    

    $vmmConnection = Get-SCVMMServer -ComputerName $env:COMPUTERNAME
                        
    Write-Verbose "Setting Custom Property: ""$PropertyName"" Value: ""$Value""."

    $null = Set-SCCustomPropertyValue -CustomProperty $retVal.CustomProperty `
                                    -InputObject $retVal.InputObject `
                                    -Value $Value `
                                    -ErrorAction Stop
}

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
        [Parameter(Mandatory=$true)]
        [String]
        $PropertyName,

        [Parameter(Mandatory=$true)]
        [String]
        $ObjectName,

        [Parameter(Mandatory=$true)]
        [String]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String]
        $Member,

        [String]
        $VMMServerName = 'localhost'
	)
     
    try
    {
        $propertyValue = Invoke-Command -ComputerName $VMMServerName `
                            -ScriptBlock  ${Function:Get-PropertyValue} `
                            -ArgumentList @(${Function:Get-PropertyObjects},
                                            $PropertyName,
                                            $ObjectName,
                                            $Member,
                                            $VerbosePreference) `
                            -ErrorAction Stop
    }
    catch
    {
        $message = $_.Exception.Message

        if($message -like "*CustomPropertyObjectNotFound*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyObjectNotFound -FormatArgs @($ObjectName, $Member) -ErrorCategory ObjectNotFound
        }
        elseif($message -like "*CustomPropertyObjectInvalidReturn*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyObjectInvalidReturn -FormatArgs @($ObjectName, $Member) -ErrorCategory InvalidResult
        } 
        elseif($message -like "*CustomPropertyNotFound2*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyNotFound2 -FormatArgs @($PropertyName) -ErrorCategory ObjectNotFound 
        }
        elseif($message -like "*CustomPropertyMemberNotFound*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyMemberNotFound -FormatArgs @($PropertyName, $Member) `
                        -ErrorCategory ObjectNotFound -TargetObject $customProperty
        }
        else
        {
            throw $_
        }
    }

    $returnValue = @{
                        PropertyName = $PropertyName
                        ObjectName = $ObjectName
                        Value = $propertyValue
                        Member = $Member    }

	$returnValue
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
        [String]
        $PropertyName,

        [Parameter(Mandatory=$true)]
        [String]
        $ObjectName,

        [Parameter(Mandatory=$true)]
        [String]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String]
        $Member,

        [String]
        $VMMServerName = 'localhost'
	)

    try
    {
        Invoke-Command -ComputerName $VMMServerName `
                        -ScriptBlock ${Function:Set-PropertyValue} `
                        -ArgumentList @(${Function:Get-PropertyObjects}, 
                                        $PropertyName,
                                        $ObjectName,
                                        $Value,
                                        $Member,
                                        $VerbosePreference) `
                        -ErrorAction Stop
    }
    catch
    {
        $message = $_.Exception.Message

        if($message -like "*CustomPropertyObjectNotFound*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyObjectNotFound -FormatArgs @($ObjectName, $Member) -ErrorCategory ObjectNotFound
        }
        elseif($message -like "*CustomPropertyObjectInvalidReturn*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyObjectInvalidReturn -FormatArgs @($ObjectName, $Member) -ErrorCategory InvalidResult
        } 
        elseif($message -like "*CustomPropertyNotFound2*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyNotFound2 -FormatArgs @($PropertyName) -ErrorCategory ObjectNotFound 
        }
        elseif($message -like "*CustomPropertyMemberNotFound*")
        {
            throw New-TerminatingError -ErrorType CustomPropertyMemberNotFound -FormatArgs @($PropertyName, $Member) `
                        -ErrorCategory ObjectNotFound -TargetObject $customProperty
        }
        else
        {
            throw $_
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
        [Parameter(Mandatory=$true)]
        [String]
        $PropertyName,

        [Parameter(Mandatory=$true)]
        [String]
        $ObjectName,

        [Parameter(Mandatory=$true)]
        [String]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloud","ComputerTier","HostCluster","ProtectionUnit","ServiceInstance",
                        "ServiceTemplate","Template","VM","VMHost","VMHostGroup")]
        [String]
        $Member,

        [String]
        $VMMServerName = 'localhost'
	)

    $retVal = Get-TargetResource @PSBoundParameters

    $result = $true

    if($retVal.Value -ne $Value)
    {
        Write-Verbose "Expected custom property value: ""$Value"" does not match actual value: ""$($retVal.Value)""."
        $result = $false
    }

	$result
}

Export-ModuleMember -Function *-TargetResource
