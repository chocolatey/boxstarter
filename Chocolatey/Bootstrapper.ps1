$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
Import-Module "$scriptPath\Boxstarter.Chocolatey.psd1"
. "$scriptPath\..\BootStrapper\AdminProxy.ps1" -ScriptToCall {Invoke-ChocolateyBoxstarter $args}