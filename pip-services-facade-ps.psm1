########################################################
##
## pip-services-facade-ps.ps1
## Client facade integration for Pip.Services
## Powershell module entry
##
#######################################################

$Script:SelectedPipConnection = $null
$Script:OpenPipConnections = @()

$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

. "$($path)/src/clients/MimeTypes.ps1"
. "$($path)/src/clients/Connections.ps1"
. "$($path)/src/clients/Conversions.ps1"
. "$($path)/src/clients/Invocations.ps1"
