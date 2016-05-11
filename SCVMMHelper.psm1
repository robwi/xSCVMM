# Set Global Module Verbose
$VerbosePreference = 'Continue' 

# Load Localization Data 
Import-LocalizedData LocalizedData -filename xVMM.strings.psd1 -ErrorAction SilentlyContinue
Import-LocalizedData USLocalizedData -filename xVMM.strings.psd1 -UICulture en-US -ErrorAction SilentlyContinue

function New-TerminatingError 
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ErrorType,

        [parameter(Mandatory = $false)]
        [String[]]
        $FormatArgs,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorCategory]

        $ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped,

        [parameter(Mandatory = $false)]
        [Object]
        $TargetObject = $null
    )

    $errorMessage = $LocalizedData.$ErrorType
    
    if(!$errorMessage)
    {
        $errorMessage = ($LocalizedData.NoKeyFound -f $ErrorType)

        if(!$errorMessage)
        {
            $errorMessage = ("No Localization key found for key: {0}" -f $ErrorType)
        }
    }

    $errorMessage = ($errorMessage -f $FormatArgs)

    $callStack = Get-PSCallStack 

    if($callStack[1] -and $callStack[1].ScriptName)
    {
        $scriptPath = $callStack[1].ScriptName

        $callingScriptName = $scriptPath.Split('\')[-1].Split('.')[0]
    
        $errorId = "$callingScriptName.$ErrorType"
    }
    else
    {
        $errorId = $ErrorType
    }

    Write-Verbose -Message "$($USLocalizedData.$ErrorType -f $FormatArgs) | ErrorType: $errorId"

    $exception = New-Object System.Exception $errorMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $ErrorCategory, $TargetObject

    return $errorRecord
}

function Assert-Module 
{ 
    [CmdletBinding()] 
    param 
    ( 
        [parameter(Mandatory = $true)]
        [string]$ModuleName
    ) 

    # This will check for all the modules that are loaded or otherwise
    if(!(Get-Module -Name $ModuleName))
    {
        if (!(Get-Module -Name $ModuleName -ListAvailable)) 
        { 
            throw New-TerminatingError -ErrorType ModuleNotFound -FormatArgs @($ModuleName) -ErrorCategory ObjectNotFound -TargetObject $ModuleName 
        }
        else
        {
            Write-Verbose -Message "PowerShell Module '$ModuleName' is installed on the $env:COMPUTERNAME"

            Write-Verbose "Loading $ModuleName Module"
           
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = "SilentlyContinue"
            $null = Import-Module -Name $ModuleName -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
        }
    }
}

function Get-VMMServerConnection
{    
    [CmdletBinding()] 
    param 
    (     
        [String]$ServerName = 'localhost'
    ) 

    Assert-Module -ModuleName VirtualMachineManager

    $CurrentVerbose = $VerbosePreference
    $VerbosePreference = "SilentlyContinue"
    $vmmConnection = Get-SCVMMServer -ComputerName $ServerName -ErrorAction Stop
    $VerbosePreference = $CurrentVerbose

    return $vmmConnection
}

function Compare-ObjectAssert
{
    [CmdletBinding()] 
	[OutputType([Boolean])]
	param
	(     
        [Object[]]
        $ExpectedArray,

        [Object[]]
        $ActualArray,

        [String]
        $MessageName,

        [String]
        [ValidateSet('Equal','Left','Right')]
        $CompareType = 'Equal'
	)

    $result = $true

    if(!$ExpectedArray)
    { 
        if($ActualArray)
        {
            Write-Verbose "Actual values found for $MessageName but no values in expected."

            return $false
        }
        else
        {
            return $true
        }
    }

    if(!$ActualArray)
    {
        if($ExpectedArray)
        {
            Write-Verbose "Expected values found for $MessageName but no values in actual."

            return $false
        }
        else
        {
            return $true
        }
    }

    $compareOutput = Compare $ExpectedArray $ActualArray

    if($compareOutput)
    {
        if($CompareType -eq 'Equal')
        {
            Write-Verbose "Expected $MessageName values do not match."

            $result = $false
        }
        elseif($CompareType -eq 'Left')
        {
            if(($compareOutput | Select-String '<='))
            {
                Write-Verbose "Expected $MessageName values not found in right side."

                $result = $false
            }
        }
        elseif($CompareType -eq 'Right')
        {
            if(($compareOutput | Select-String '=>'))
            {
                Write-Verbose "Expected $MessageName values not found in left side."

                $result = $false
            }
        }

        if(!$result)
        {
            Write-Verbose ($compareOutput | Out-String)
        }
    }

    $result
}

# Creates the key if not found
function Get-RegistryKeyValue
{            
    [CmdletBinding()] 
    param 
    (     
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [String]$Key,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [String]$KeyName
    ) 

    $functionName = $($MyInvocation.MyCommand.Name) + ":"

    $regEntry = $null
    $regEntry = Get-ItemProperty -Path $Key -Name $KeyName -ErrorAction SilentlyContinue

    if($regEntry -eq $null) 
    {
        # If we don't find the key then this is the first time we ran this code, we create and set it.
        if (!(Test-Path -Path $Key))
        {
            Write-Verbose "$functionName Creating a new registry path Key '$Key' on $env:COMPUTERNAME" -Verbose
            $null = New-Item -Path $Key -ErrorAction Stop
        }
        Write-Verbose "$functionName Creating a new  Key with name '$KeyName' with value '$true' on $env:COMPUTERNAME" -Verbose
        Set-ItemProperty -Path $Key -Name $KeyName -Value $true -ErrorAction Stop
        
        return $true
    } 
    else 
    {                
        Write-Verbose "$functionName Found Key $Key with key name $KeyName and value '$($regEntry.$KeyName)'" -Verbose
        return $regEntry.$KeyName
    }
}