$here = Split-Path -parent $MyInvocation.MyCommand.Definition

# Import the Chocolatey module first so that $Boxstarter properties
# are initialized correctly and then import everything else.
$mpath = "$here/Boxstarter.Chocolatey/Boxstarter.Chocolatey.psd1"
Write-Host "=> $mpath"
Import-Module $mpath -DisableNameChecking -ErrorAction SilentlyContinue
Resolve-Path $here/Boxstarter.*/*.psd1 |
    ForEach-Object { 
        Write-Host "=> $_"
        Import-Module $_.ProviderPath -DisableNameChecking -ErrorAction SilentlyContinue 
    }
Import-Module $here/Boxstarter.Common/Boxstarter.Common.psd1 -Function Test-Admin


if(!(Test-Admin)) {
    Write-BoxstarterMessage "Not running with administrative rights. Attempting to elevate..."
    if ($PSVersionTable.Platform -eq 'Unix') {
        Write-BoxstarterMessage "nevermind, this is a Unix system, will use *sudo powers* when necessary"
    } else {
        $command = "-ExecutionPolicy bypass -noexit -command &'$here\BoxstarterShell.ps1'"
        Start-Process powershell -verb runas -argumentlist $command
        Exit
    }
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

For Boxstarter documentation, source code, to report bugs or participate in discussions, please visit https://boxstarter.org
"@
