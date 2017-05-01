########################################################
##
## Invocations.ps1
## Client facade integration for Pip.Services
## REST/JSON invocations
##
#######################################################


function FixUnsafeHeaders
{
    $netAssembly = [Reflection.Assembly]::GetAssembly([System.Net.Configuration.SettingsSection])

    if ($netAssembly)
    {
        $bindingFlags = [Reflection.BindingFlags] "Static,GetProperty,NonPublic"
        $settingsType = $netAssembly.GetType("System.Net.Configuration.SettingsSectionInternal")

        $instance = $settingsType.InvokeMember("Section", $bindingFlags, $null, $null, @())

        if ($instance)
        {
            $bindingFlags = "NonPublic","Instance"
            $useUnsafeHeaderParsingField = $settingsType.GetField("useUnsafeHeaderParsing", $bindingFlags)

            if ($useUnsafeHeaderParsingField)
            {
              $useUnsafeHeaderParsingField.SetValue($instance, $true)
            }
        }
    }
}


function UploadFile 
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $Uri,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $Method,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $InFile
    )
    process 
    {
        if (-not (Test-Path $InFile))
        {            
            throw "File $InFile is missing or unable to read."
        }
 
        $mimeType = Get-MimeType($InFile)
        if ($mimeType) { $ContentType = $mimeType }
        else { $ContentType = "application/octet-stream" }

        $httpClient = New-Object System.Net.Http.HttpClient
 
        $file = Get-Item -Path $InFile
        $stream = New-Object System.IO.FileStream @($file.FullName, [System.IO.FileMode]::Open)
        
		$contentDisposition = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue "form-data"
	    $contentDisposition.Name = "fileData"
		$contentDisposition.FileName = (Split-Path $InFile -leaf)
 
        $streamContent = New-Object System.Net.Http.StreamContent $stream
        $streamContent.Headers.ContentDisposition = $contentDisposition
        $streamContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue $ContentType
        
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $content.Add($streamContent)
 
		$response = $httpClient.PostAsync($Uri, $content).Result

        $result = @{ StatusCode = $response.StatusCode; Content = $response.Content.ReadAsStringAsync().Result }

        Write-Output New-Object -Type PSObject -Prop $result
    }
}


function Invoke-PipFacade 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [Hashtable] $Connection,
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
        [string] $Name,
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipelineByPropertyName=$true)]
        [string] $Method = "Get",
        [Parameter(Mandatory=$true, Position = 1, ValueFromPipelineByPropertyName=$true)]
        [string] $Route,
        [Parameter(Mandatory=$false, Position = 2, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Params = @{},
        [Parameter(Mandatory=$false, Position = 3, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Object] $Request = $null,
        [Parameter(Mandatory=$false, Position = 4, ValueFromPipelineByPropertyName=$true)]
        [string] $InFile = $null,
        [Parameter(Mandatory=$false, Position = 5, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Headers = @{},
        [Parameter(Mandatory=$false, Position = 6, ValueFromPipelineByPropertyName=$true)]
        [bool] $RawResult = $false
    )
    begin {}
    process 
    {
        ## Get gateway session
        $Connection = if ($Connection -eq $null) { Get-PipConnection -Name $Name } else {$Connection}
        if ($Connection -eq $null) 
        {
            throw "PipConnection is not defined. Please, use Open-PipConnection or Select-PipConnection"
        }

        ## Construct URI with parameters
        $uri = $Connection.Protocol + "://" + $Connection.Host + ":" + $Connection.Port + $Route;

        # Combine all headers
        $allHeaders = $Connection.Headers + $Headers

        $result = Invoke-PipRest -Method $Method -Uri $uri -Params $Params -Request $Request -InFile $InFile -Headers $allHeaders -RawResult $RawResult
 
        Write-Output $result
    }
    end{}
}


function Invoke-PipRest 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipelineByPropertyName=$true)]
        [string] $Method = "Get",
        [Parameter(Mandatory=$true, Position = 1, ValueFromPipelineByPropertyName=$true)]
        [string] $Uri,
        [Parameter(Mandatory=$false, Position = 2, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Params = @{},
        [Parameter(Mandatory=$false, Position = 3, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Object] $Request = $null,
        [Parameter(Mandatory=$false, Position = 4, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $InFile,
        [Parameter(Mandatory=$false, Position = 5, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Headers = @{},
        [Parameter(Mandatory=$false, Position = 6, ValueFromPipelineByPropertyName=$true)]
        [bool] $RawResult = $false
    )
    begin {}
    process 
    {
        # Add query parameters to uri
        $query = ""
        foreach ($paramName in $Params.Keys) 
        {
            $paramValue = $Params[$paramName]
            $paramValue = [System.Net.WebUtility]::HtmlEncode($paramValue)
            if ($query -eq "") { $query = "?" } else { $query += "&" }
            $query += $paramName + "=" + $paramValue
        }
        $uri += $query;

        ## Hack to fix unsafe headers to prevent Invoke-WebRequest from failing
        # Todo: Temporary disabled
        #FixUnsafeHeaders

        if ($InFile -ne '')
        {
            $response = UploadFile -Uri $Uri -Method $Method -InFile $InFile
        }
        else
        {
            ## Serialize input data
            $body = if ($Request -ne $null) { ConvertTo-Json $Request } else { $null }


            ## Define additional parameters
            $contentType = "application/json"
            $userAgent = "Pip.Facade PowerShell Client"

            ## Call the facade
            $response = Invoke-WebRequest -Uri $Uri -Method $Method -UserAgent $userAgent -Headers $Headers -ContentType $contentType -Body $body -UseBasicParsing
        }

        ## Process null response
        if ($response -eq $null) 
        {
            ##throw "Facade returned empty response"
            Write-Output $response
        } 
        ## Process empty response
        elseif ($response.StatusCode -eq 204) 
        {
            Write-Output $null
        } 
        ## Process normal JSON response
        elseif ($response.StatusCode -lt 400) 
        {
            if ($RawResult) 
            {
                $data = $response.Content
            } 
            else 
            {
                $data = if (![string]::IsNullOrWhiteSpace($response.Content)) { ConvertFrom-Json $response.Content } else { $null }
            }
            Write-Output $data
        } 
        ## Process server errors
        ## Todo: Improve error handling for standard errors
        elseif ($response.StatusCode -eq 500) 
        {
            $error = if (![string]::IsNullOrWhiteSpace($response.Content)) { ConvertFrom-Json $response.Content } else { "Facade returned error: $($response.StatusCode) " }
            throw $error
        } 
        ## Process general errors
        else 
        {
            throw if ([string]::IsNullOrWhiteSpace($response.Content)) { $response.Content } else { "Error code $($response.StatusCode)" }
        }
    }
    end {}
}
