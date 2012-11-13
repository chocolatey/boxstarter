$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
$isAdmin = $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
$command = "Import-Module `"$scriptPath\BoxStarter.psm1`";Invoke-BoxStarter $args"
if($isAdmin) {  
  Invoke-Expression $command
}
else {
  $command = "-ExecutionPolicy bypass -noexit -command " + $command
  Start-Process powershell -verb runas -argumentlist $command
}
