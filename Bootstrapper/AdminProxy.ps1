$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. "$scriptPath\Write-BoxstarterMessage.ps1"
. "$scriptPath\Log-BoxStarterMessage.ps1"
. "$scriptPath\Format-BoxStarterMessage.ps1"

$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
$isAdmin = $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
$command = "Import-Module `"$scriptPath\BoxStarter.psm1`";. '$scriptPath\Tee-BoxstarterLog.ps1';Invoke-BoxStarter $args 2>&1 | Tee-BoxstarterLog"
if($isAdmin) { 
  Write-BoxstarterMessage "Starting in an elevated console"
  Invoke-Expression $command
}
else {
  Write-BoxstarterMessage "User is not running with administrative rights. Attempting to elevate."
  $command = "-ExecutionPolicy bypass -noexit -command " + $command
  Start-Process powershell -verb runas -argumentlist $command
}