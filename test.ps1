
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1
write-host "hi1"
start-sleep -s 5
write-host "hi2"
