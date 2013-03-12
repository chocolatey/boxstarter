if($Boxstarter.Config.LocalRepo -ne $null){
    $BoxStarter.LocalRepo=$Boxstarter.Config.LocalRepo
} else {
    if($Boxstarter.baseDir){
        $Boxstarter.localRepo=(Join-Path $Boxstarter.baseDir BuildPackages)
    }
}
$Boxstarter.NugetSources=$Boxstarter.Config.NugetSources
$Boxstarter.RebootOk=$true
function Invoke-ChocolateyBoxstarter{
<#
.SYNOPSIS
Invokes the installation of a Boxstarter package

.DESCRIPTION
This essentially wraps Chocolatey Install and provides these additional features
 - Installs chocolatey if it is not already installed
 - Installs the .net 4.0 framework if it is not installed which is a chocolatey requirement
 - Turns off the windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.WinConfig module that provides functions for customizing windows
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under admin

 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget
 This can be configured by editing $($Boxstarter.BaseDir)\Boxstarter.Config

 .PARAMETER BootstrapPackage
 The package to be installed.
 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

.Parameter Localrepo
This is the path to the local boxstarter repository where boxstarter 
should look for .nupkg files to install. By default this is located 
in the BuildPackages directory just under the root Boxstarter 
directory.

.PARAMETER DisableReboots
If set, reboots are subbressed.

.EXAMPLE
Invoke-ChocolateyBoxstarter example

This invokes boxstarter and installs the example .nupkg. In pending 
reboots are detected, boxstarter will restart the machine. Boxstarter
will prompt the user to enter a password which will be used for 
automatic logins in the event a restart is required.

.EXAMPLE
Invoke-ChocolateyBoxstarter win8Install -LocalRepo \\server\share\boxstarter

This installs the Win8Install .nupkg and specifies that it is ok to 
reboot the macine if a pending reboot is needed. Boxstarter will look 
for the Win8Install .nupkg file in the \\serer\share\boxstarter 
directory.

.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
#>    
    [CmdletBinding()]
    param(
      [string]$bootstrapPackage="default",
      [string]$localRepo,
      [switch]$DisableReboots
    )
    if($DisableReboots){$Boxstarter.RebootOk=$false}
    if(!$Boxstarter.ScriptToCall){
        $script=@"
Import-Module (Join-Path "$($Boxstarter.baseDir)" BoxStarter.Chocolatey\Boxstarter.Chocolatey.psd1) -global -DisableNameChecking;
Invoke-ChocolateyBoxstarter -bootstrapPackage $bootstrapPackage $(if($LocalRepo){"-Localrepo $localRepo"})
"@
        Invoke-Boxstarter ([ScriptBlock]::Create($script)) -RebootOk:$Boxstarter.RebootOk
        return
    }
    if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
    $Boxstarter.ProgramFiles86="$programFiles86"
    $Boxstarter.ChocolateyBin="$env:systemdrive\chocolatey\bin"
    $Boxstarter.Package=$bootstrapPackage
    $Boxstarter.LocalRepo=Resolve-LocalRepo $localRepo
    Check-Chocolatey -ShouldIntercept
    del "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -ErrorAction SilentlyContinue
    del "$env:systemdrive\chocolatey\lib\$bootstrapPackage.*" -recurse -force -ErrorAction SilentlyContinue
    Download-Package $bootstrapPackage
}

function Resolve-LocalRepo([string]$localRepo) {
    if($localRepo){
        $localRepo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($localRepo)
    } else {$Localrepo = $Boxstarter.Localrepo}
    write-BoxstarterMessage "LocalRepo is at $localRepo"
    return $localRepo
}

function Download-Package([string]$bootstrapPackage) {
    if(test-path (Join-Path $Boxstarter.LocalRepo "$bootstrapPackage.*.nupkg")){
        $source = $Boxstarter.LocalRepo
    } else {
        $source = $Boxstarter.Config.NugetSources
    }
    write-BoxstarterMessage "Installing $bootstrapPackage package from $source"
    Chocolatey install $bootstrapPackage -source $source -force
}