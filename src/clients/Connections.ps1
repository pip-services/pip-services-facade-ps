########################################################
##
## Connections.ps1
## Client facade integration for Pip.Services
## Connection management to client facades
##
#######################################################

function Open-PipConnection 
{
<#
.SYNOPSIS

Opens a new connection with client facade

.DESCRIPTION

Open-PipConnection opens a new connection with client facade

.PARAMETER Name (default: "default")

A name to refer to the client facade

.PARAMETER Protocol

A facade communication protocol (default: http)

.PARAMETER Host

A facade hostname or IP address

.PARAMETER Port

A facade port to access the cluster (default: 80)

.PARAMETER Headers

A HTTP headers to be attached to every request

.EXAMPLE

PS> $test = Open-PipConnection -Name "test" -Host "172.16.141.175" -Post 28800

#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipelineByPropertyName=$true)]
        [string] $Name = "default",
        [Parameter(Mandatory=$false, Position = 1, ValueFromPipelineByPropertyName=$true)]
        [string] $Protocol = "http",
        [Parameter(Mandatory=$true, Position = 2, ValueFromPipelineByPropertyName=$true)]
        [string] $Host,
        [Parameter(Mandatory=$false, Position = 3, ValueFromPipelineByPropertyName=$true)]
        [int] $Port = 80,
        [Parameter(Mandatory=$false, Position = 4, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Headers = @{}
    )
    begin {}
    process 
    {
        $connection = @{ Name=$Name; Protocol=$Protocol; Host=$Host; Port=$Port; Headers=$Headers }
        $Script:SelectedPipConnection = $connection
        $Script:OpenPipConnections = $OpenPipConnections | Where-Object { $_.Name -ne $Name }
        ## We had problems with adding elements in PS 6.0 Alpha
        if ($OpenPipConnections -eq $null) {
            $Script:OpenPipConnections = @( $connection )
        } elseif ($OpenPipConnections.GetType().IsArray -eq $false) {
            $Script:OpenPipConnections = @( $OpenPipConnections, $connection )
        } else {
            $Script:OpenPipConnections += $connection
        }
        Write-Output $connection
    }
    end {}
}


function Get-PipConnection 
{
<#
.SYNOPSIS

Gets a connection with client facade

.DESCRIPTION

Get-PipConnection gets previously opened connection with client facade

.PARAMETER Name

A name to refer to the client facade

.EXAMPLE

# Get currently selected connection
PS> Get-PipConnection

# Get connection by name
PS> Get-PipConnection -Name test

#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Name
    )
    begin {}
    process 
    {
        # Get a connection by name
        $connection = $OpenPipConnections | Where-Object { $_.Name -eq $Name }
        
        # Get selected (default) connection
        $connection = if ($connection -ne $null) {$connection} else {$SelectedPipConnection}

        Write-Output $connection
    }
    end {}
}


function Select-PipConnection 
{
<#
.SYNOPSIS

Selects previously opened connection with client facade

.DESCRIPTION

Select-PipConnection selects previously opened connection with client facade

.PARAMETER Connection

A object with connection parameters

.PARAMETER Name

A name to refer to the client facade

.EXAMPLE

# Set currently selected connection
PS> Select-PipConnection -Connection $test

# Select connection by name
PS> Select-PipConnection -Name "test"

#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Connection,
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Name
    )
    begin {}
    process 
    {
        if ($Connection -eq $null) 
        {
            $Connection = $OpenPipConnections | Where-Object { $_.Name -eq $Name }
        }
        
        $Script:SelectedPipConnection = $Connection

        Write-Output $Connection
    }
    end {}
}


function Close-PipConnection 
{
<#
.SYNOPSIS

Closes connection with client facade

.DESCRIPTION

Close-PipConnection closes previously opened connection with client facade.
The connection can be identified by object or by name.
If no connection is specified, then the active connection is taken

.PARAMETER Connection

A connection object

.PARAMETER Name

A name to refer to the client facade

.PARAMETER All

Forces to close all open connections

.EXAMPLE

# Closes current connection
PS> Close-PipConnection

# Closes connection by name
PS> Close-PipConnection -Name "test"

# Closes all open connections
PS> Close-PipConnection -All $true

#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Hashtable] $Connection,
        [Parameter(Mandatory=$false, Position = 0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Name,
        [Parameter(Mandatory=$false)]
        [bool] $All = $false
    )
    begin {}
    process {
        if ($All) 
        {
            $Script:OpenPipConnections = @()
            $Script:SelectedPipConnection = $null
        } 
        else 
        {
            $Connection = if ($Connection -ne $null) {$Connection} else {$SelectedPipConnection}
            $Name = if ([string]::IsNullOrWhiteSpace($Name)) {$Connection.Name} else {$Name}

            $Script:OpenPipConnections = @() + ( $OpenPipConnections | Where-Object { $_.Name -ne $Name } )

            $Script:SelectedPipConnection = if ($SelectedPipConnection.Name -ne $Name) {$SelectedPipConnection} else {$null}
            if (($SelectedPipConnection -eq $null) -and ($OpenPipConnections.Count > 0)) 
            {
                $Script:SelectedPipConnection = $OpenPipConnections[0]
            }
        }
    }
    end {}
}
