function Invoke-ChocolateyBoxstarter{
<#
.SYNOPSIS
Invokes the installation of a Boxstarter package

.DESCRIPTION
This essentially wraps Chocolatey Install and provides these additional features
 - Installs chocolatey if it is not already installed
 - Installs the .net 4.0 framework if it is not installed which is a chocolatey requirement
 - Turns off the windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.Helpers module that provides functions for customizing windows
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under admin

 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

 .PARAMETER BootstrapPackage
 The package to be installed.
 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

.Parameter Password
This password will be used to automatically log the user in if a 
reboot is required and reboots are eabled.

.Parameter RebootOk
If set, a reboot will be performed if boxstarter determines that a 
reboot is pending. Boxstarter will prompt the user to enter a 
password which will be used for automatic logins in the event a 
restart is required.

.Parameter ReEnableUAC
This parameter is intended to be set by Boxstarter If boxstarter 
needs to disable UAC in order to suppress the security prompt 
after reboot when relaunching boxstarter as admin, it will set 
this switch which will cause boxstarter to turn UAC back on aftr 
the reboot completes.

.Parameter Localrepo
This is the path to the local boxstarter repository where boxstarter 
should look for .nupkg files to install. By default this is located 
in the BuildPackages directory just under the root Boxstarter 
directory.

.EXAMPLE
Invoke-Boxstarter example -RebootOk

This invokes boxstarter an installs the example .nupkg. In pending 
reboots are detected, boxstarter will restart the machine. Boxstarter
will prompt the user to enter a password which will be used for 
automatic logins in the event a restart is required.

.EXAMPLE
Invoke-Boxstarter win8Install -rebootOk -LocalRepo \\server\share\boxstarter

This installs the Win8Install .nupkg and specifies that it is ok to 
reboot the macine if a pending reboot is needed. Boxstarter will look 
for the Win8Install .nupkg file in the \\serer\share\boxstarter 
directory.

.LINK
http://boxstarter.codeplex.com
About_Boxstarter_Variable
#>    
    [CmdletBinding()]
    param(
      [string]$bootstrapPackage="default",
      [string]$localRepo="$baseDir\BuildPackages"
    )
        if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
        $Boxstarter.ProgramFiles86="$programFiles86"
        $Boxstarter.ChocolateyBin="$env:systemdrive\chocolatey\bin"
        $Boxstarter.Package=$bootstrapPackage
        $Boxstarter.LocalRepo=Resolve-LocalRepo $localRepo
        Check-Chocolatey
        del "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -ErrorAction SilentlyContinue
        del "$env:systemdrive\chocolatey\lib\$bootstrapPackage.*" -recurse -force -ErrorAction SilentlyContinue
        Get-HelperModule
        Download-Package $bootstrapPackage
}

function Resolve-LocalRepo([string]$localRepo) {
    if($localRepo){
        $localRepo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($localRepo)
    }
    write-BoxstarterMessage "LocalRepo is at $localRepo"
    return $localRepo
}

function Get-HelperModule {
    if(Test-Path (Join-Path $Boxstarter.LocalRepo "boxstarter.Helpers.*.nupkg")) { 
        $helperSrc = $Boxstarter.LocalRepo
    }
    Chocolatey update boxstarter.helpers $helperSrc
    Try-LoadHelpers
    if(Get-Module Boxstarter.Helpers){
        $mod=Get-Module Boxstarter.Helpers
        write-BoxstarterMessage "Loaded Boxstarter.Helpers version $($mod.Version.ToString())"
    }
}

function Try-LoadHelpers {
    $helperDir = (Get-ChildItem $env:ChocolateyInstall\lib\boxstarter.helpers*)
    if($helperDir.Count -gt 1){$helperDir = $helperDir[-1]}
    if($helperDir) { 
        if(Get-Module boxstarter.helpers){Remove-Module boxstarter.helpers}
        import-module $helperDir\boxstarter.helpers.psm1 
    }
}

function Download-Package([string]$bootstrapPackage) {
    if(test-path (Join-Path $Boxstarter.LocalRepo "$bootstrapPackage.*.nupkg")){
        $source = $Boxstarter.LocalRepo
    } else {
        $source = "http://chocolatey.org/api/v2;http://www.myget.org/F/boxstarter/api/v2"
    }
    write-BoxstarterMessage "Installing $bootstrapPackage package from $source"
    Chocolatey install $bootstrapPackage -source $source -force
}