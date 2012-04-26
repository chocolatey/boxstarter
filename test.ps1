
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\VsixInstallFunctions.ps1
InstallVsixSilently http://visualstudiogallery.msdn.microsoft.com/463c5987-f82b-46c8-a97e-b1cde42b9099/file/66837/1/xunit.runner.visualstudio.vsix xunit.runner.visualstudio.vsix "11.0"
