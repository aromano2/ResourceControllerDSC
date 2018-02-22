﻿function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param
    (      
        [Parameter(Mandatory = $true)]
        [string]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceName,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]] 
        $Properties,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]] 
        $Result,

        [Parameter()]
        [Boolean]
        $SupressReboot,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $MaintenanceWindow
    )

    $functionName = "Get-TargetResource"

    $PropertiesHashTable = @{}
    foreach($prop in $Properties)
    {
        $PropertiesHashTable.Add($prop.Key, $prop.Value)
    }

    $dscResource = Get-DscResource -Name $ResourceName

    Import-Module $dscResource.Path -Function $functionName -Prefix $ResourceName
    
    try
    {
        Test-ParameterValidation -Name $functionName.Replace("-","-$ResourceName") -Values $PropertiesHashTable
    }
    catch
    {
        throw $_.Exception.Message
    }

    $splatProperties = Get-ValidParameters -Name $functionName.Replace("-","-$ResourceName") -Values $PropertiesHashTable
            
    $get = & "Get-${ResourceName}TargetResource" @splatProperties

    $CimGetResults = New-Object -TypeName 'System.Collections.ObjectModel.Collection`1[Microsoft.Management.Infrastructure.CimInstance]'

    foreach($row in $get.Keys.GetEnumerator())
    {
        $value = $get.$row

        $CimProperties = @{
            Namespace = 'root/Microsoft/Windows/DesiredStateConfiguration'
            ClassName = "MSFT_KeyValuePair"
            Property = @{
                            Key = "$row"
                            Value = "$value"
                        }
        }
        $CimGetResults += New-CimInstance -ClientOnly @CimProperties
    }

    $returnValue = @{
        InstanceName = $InstanceName
        ResourceName = $ResourceName
        Properties = $Properties
        Result = $CimGetResults
        SupressReboot = $SupressReboot
        MaintenanceWindow = $MaintenanceWindow
    }
    
    return $returnValue
}

function Test-TargetResource
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceName,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]] 
        $Properties,

        [Parameter()]
        [Boolean]
        $SupressReboot,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $MaintenanceWindow
    )

    $functionName = "Test-TargetResource"

    $PropertiesHashTable = @{}
    foreach($prop in $Properties)
    {
        $PropertiesHashTable.Add($prop.Key, $prop.Value)
    }

    $dscResource = Get-DscResource -Name $ResourceName

    Import-Module $dscResource.Path -Function $functionName -Prefix $ResourceName
    
    try
    {
        $null = Test-ParameterValidation -Name $functionName.Replace("-","-$ResourceName") -Values $PropertiesHashTable
    }
    catch
    {
        throw $_.Exception.Message
    }

    $splatProperties = Get-ValidParameters -Name $functionName.Replace("-","-$ResourceName") -Values $PropertiesHashTable
            
    $result = &"Test-${ResourceName}TargetResource" @splatProperties
    
    return $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $InstanceName,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceName,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]] 
        $Properties,

        [Parameter()]
        [Boolean]
        $SupressReboot,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $MaintenanceWindow
    )

    foreach($window in $MaintenanceWindow)
    {
        $maintenanceWindowProperties = @{}
        $params = @("Frequency",
                    "StartTime",
                    "EndTime",
                    "DaysofWeek",
                    "Week",
                    "Days",
                    "StartDate",
                    "EndDate")

        foreach($param in $params)
        {
            if($window.$param)
            {
                $maintenanceWindowProperties.Add($param, $window.$param)
            }
        }

        if(-not $(Test-MaintenanceWindow @maintenanceWindowProperties))
        {
            Write-Verbose "You are outside the maintenance window. No changes will be made."
            return
        }
    }    

    $functionName = "Set-TargetResource"

    $PropertiesHashTable = @{}
    foreach($prop in $Properties)
    {
        $PropertiesHashTable.Add($prop.Key, $prop.Value)
    }
    
    $dscResource = Get-DscResource -Name $ResourceName

    Import-Module $dscResource.Path -Function $functionName -Prefix $ResourceName
    
    try
    {
        Test-ParameterValidation -Name $functionName.Replace("-","-$ResourceName") -Values $PropertiesHashTable
    }
    catch
    {
        throw $_.Exception.Message
    }
    
    $splatProperties = Get-ValidParameters -Name $functionName.Replace("-","-$ResourceName") -Values $PropertiesHashTable
    
    &"Set-${ResourceName}TargetResource" @splatProperties -Verbose

    if($SupressReboot)
    {
        $global:DSCMachineStatus = 0
    }
}

function Test-MaintenanceWindow
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Frequency,

        [Parameter()]
        [Nullable[DateTime]]
        $StartTime,

        [Parameter()]
        [Nullable[DateTime]]
        $EndTime,

        [Parameter()]
        [string[]]
        $DaysofWeek,

        [Parameter()]
        [int[]]
        $Week,

        [Parameter()]
        [int[]]
        $Days,

        [Parameter()]
        [Nullable[DateTime]]
        $StartDate,

        [Parameter()]
        [Nullable[DateTime]]
        $EndDate
    )

    $Now = Get-Date

    if($StartDate -and $EndDate)
    {
        if($StartDate -ge $EndDate)
        {
            throw "StartDate cannot be after the EndDate"
        }
    }

    if(-not $StartDate)
    {
        $StartDate = [DateTime]::MinValue
    }

    if(-not $EndDate)
    {
        $EndDate = [DateTime]::MaxValue
    }

    $StartDate = Get-Date -Date $StartDate -Hour 0 -Minute 0 -Second 0 -Millisecond 0
    $EndDate = Get-Date -Date $EndDate -Hour 23 -Minute 59 -Second 59 -Millisecond 999

    if($Now -lt $StartDate -or $Now -gt $EndDate)
    {
        return $false
    }

    if(-not $EndTime)
    {
        $EndTime = Get-Date -Date $Now -Hour 23 -Minute 59 -Second 59 -Millisecond 999
    }
    else
    {
        $EndTime = Get-Date -Date $Now -Hour $EndTime.Hour -Minute $EndTime.Minute -Second $EndTime.Second -Millisecond $EndTime.Millisecond
    }

    if(-not $StartTime)
    {
        $StartTime = Get-Date -Date $Now -Hour 0 -Minute 0 -Second 0 -Millisecond 0
    }
    else
    {
        $StartTime = Get-Date -Date $Now -Hour $StartTime.Hour -Minute $StartTime.Minute -Second $StartTime.Second -Millisecond $StartTime.Millisecond
    }

    switch ($Frequency)
    {
        'Daily' {

            if(-not $DaysofWeek)
            {
                throw "Error"
            }

            if(-not ($DaysofWeek -Contains $now.DayOfWeek))
            {
                return $false
            }
        }
        'Weekly' {
            
            if(-not $DaysofWeek -or -not $Week)
            {
                throw "Error"
            }

            if(-not ($DaysofWeek -Contains $now.DayOfWeek))
            {
                return $false
            }

            $dow = $now.DayOfWeek
            $WorkingDate = Get-Date -Year $Now.Year -Month $Now.Month -Day 1
            $weekCount = 0

            for($i = 1; $i -le $now.Day; $i++){
                if($WorkingDate.DayOfWeek -eq $dow)
                {
                    $weekCount++
                }
                $WorkingDate = $WorkingDate.AddDays(1)
            }

            if(-not ($Week -contains $weekCount))
            {
                #check if last day
                if($Week -contains 0)
                {
                    $WorkingDate = Get-Date -Year $Now.Year -Month $Now.Month -Day $([DateTime]::DaysInMonth($Now.Year,$Now.Month))
                    while($dow -ne $WorkingDate.DayOfWeek)
                    {
                        $WorkingDate = $WorkingDate.AddDays(-1)
                    }
                    if($WorkingDate.Day -ne $now.Day)
                    {
                        return $false
                    }
                }
                else
                {
                    return $false
                }
            }
        }
        'Monthly' {

            if(-not $Days)
            {
                throw "error"
            }
            if(-not ($Days -contains $Now.Day))
            {
                if($Days -contains 0)
                {
                    $lastDayofMonth = $([DateTime]::DaysInMonth($Now.Year,$Now.Month))
                    if($lastDayofMonth -ne $Now.Day)
                    {
                        return $false
                    }
                }
                else
                {
                    return $false
                }
            }
        }
    }

    if($Now -lt $StartTime -or $now -gt $EndTime)
    {
        return $false
    }

    return $true
}

function Assert-Validation
{
    param(
        [parameter(Mandatory = $true)]
        $element,

        [parameter(Mandatory = $true)]
        [psobject]
        $ParameterMetadata
    )

    $BindingFlags = 'static','nonpublic','instance'
    $errorMessage = @()
    foreach($attribute in $ParameterMetadata.Attributes)
    {
        try
        {  
            $Method = $attribute.GetType().GetMethod('ValidateElement',$BindingFlags)
            if($Method)
            {
                $Method.Invoke($attribute,@($element))
            }

        }
        catch
        {
            $errorMessage += "Error on parameter $($ParameterMetadata.Name): $($_.Exception.InnerException.Message)"
        }
    }
    if($errorMessage.Count -gt 0)
    {
        throw $errorMessage -join "`n"
    }
}

function Test-ParameterValidation
{
    param(

        [parameter(Mandatory = $true)]
        [string]
        $Name,

        [parameter(Mandatory = $true)]
        [Hashtable]
        $Values
    )

    $ignoreResourceParameters = [System.Management.Automation.Cmdlet]::CommonParameters + [System.Management.Automation.Cmdlet]::OptionalCommonParameters
    $errorMessage = @()
    $command = Get-Command -Name $name
    $parameterNames = $command.Parameters
    foreach($name in $parameterNames.Keys)
    {
        if($ignoreResourceParameters -notcontains $name)
        {
            $metadata = $command.Parameters.$($name)
            if($Values.$($name))
            {
                try
                {
                    Assert-Validation -element $Values.$($name) -ParameterMetadata $metadata
                }
                catch
                {
                    $errorMessage += $_.Exception.Message
                }
            }
            elseif($($metadata.Attributes | Where-Object {$_.TypeId.Name -eq "ParameterAttribute"}).Mandatory)
            {
                $errorMessage += "Parameter '$name' is mandatory."
            }
        }
    }
    if($errorMessage.Count -gt 0)
    {
        throw $errorMessage -join "`n"
    }
}

function Get-ValidParameters
{
    param(

        [parameter(Mandatory = $true)]
        [string]
        $Name,

        [parameter(Mandatory = $true)]
        [Hashtable]
        $Values
    )

    $ignoreResourceParameters = [System.Management.Automation.Cmdlet]::CommonParameters + [System.Management.Automation.Cmdlet]::OptionalCommonParameters
    $command = Get-Command -Name $name
    $parameterNames = $command.Parameters
    $properties = @{}
    foreach($name in $parameterNames.Keys)
    {
        if($ignoreResourceParameters -notcontains $name)
        {
            if($Values.ContainsKey($name))
            {
                $properties.Add($Name, $Values.$name)
            }
        }
    }
    return $properties
}

Export-ModuleMember -Function *-TargetResource
