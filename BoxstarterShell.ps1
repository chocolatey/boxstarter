$here = Split-Path -parent $MyInvocation.MyCommand.Definition
Resolve-Path $here\Boxstarter.*\*.psd1 | 
    % { Import-Module $_.ProviderPath -DisableNameChecking -Force -ErrorAction SilentlyContinue }
Import-Module $here\Boxstarter.Common\Boxstarter.Common.psd1 -Function Test-Admin

if(!(Test-Admin)) {
    Write-BoxstarterMessage "Not running with administrative rights. Attempting to elevate..."
    $command = "-ExecutionPolicy bypass -noexit -command &$here\BoxstarterShell.ps1"
    Start-Process powershell -verb runas -argumentlist $command
    Exit
}

$Host.UI.RawUI.WindowTitle="Boxstarter Shell"
cd $env:SystemDrive\
Write-Output @"
Welcome to the Boxstarter shell!
The Boxstarter commands have been imported from $here and are available for you to run in this shell.
You may also import them into the shell of your choice. 

Here are some commands to get you started:
Install a Package:   Install-BoxstarterPackage
Create a Package:    New-BoxstarterPackage
Build a Package:     Invoke-BoxstarterBuild
Enable a VM:         Enable-BoxstarterVM
For Command help:    Get-Help <Command Name> -Full

For Boxstarter documentation, source code, to report bugs or participate in discussions, please visit http://boxstarter.org
"@