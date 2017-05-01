########################################################
##
## Conversions.ps1
## Client facade integration for Pip.Services
## Data conversions
##
#######################################################

function ConvertFilterParamsToString 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $InputObject
    )
    begin {}
    process 
    {
        if ($null -eq $InputObject) { return $null }

        $result = ""
        $first = $true
        foreach ($key in $InputObject.Keys) 
        {
            if (-not $first) 
            { 
                $result += ";"
            }
            $result += $key + "=" + $InputObject[$key]
            $first = $false
        }

        Write-Output $result
    }
    end {}
}

function ConvertObjectToHashtable 
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$False, Position = 0, ValueFromPipeline=$True)]
        [Object] $InputObject = $null
    )
    process 
    {
        if ($null -eq $InputObject) { return @{} }

        if ($InputObject -is [Hashtable]) 
        {
            $InputObject
        } 
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) 
        {
            $collection = 
            @(
                foreach ($object in $InputObject) { ConvertObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) 
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) 
            {
                $hash[$property.Name] = ConvertObjectToHashtable $property.Value
            }

            $hash
        }
        else 
        {
            $InputObject
        }
    }
}
