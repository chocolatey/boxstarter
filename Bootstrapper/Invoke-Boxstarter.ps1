$Boxstarter = @{ProgramFiles86="$programFiles86";ChocolateyBin="$env:systemdrive\chocolatey\bin";Log="$env:temp\boxstarter.log";RebootOk=$false}

function Invoke-BoxStarter{
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

 .PARAMETER bootstrapPackage
 The package to be installed.
 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

#>    
    [CmdletBinding()]
    param(
      [string]$bootstrapPackage="default",
      [System.Security.SecureString]$password,
      [switch]$RebootOk,
      [string]$localRepo="$baseDir\BuildPackages"
    )
    try{
        $autoLogon=Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -ErrorAction Ignore
        if($autoLogon) {$autoLogon = $autoLogon.AutoAdminLogon} else {$autoLogon=0}
        if($RebootOk -and !$Password -and ($autoLogon -lt 1)) {
            $Password=Read-Host -AsSecureString "Autologon Password"
        }
        $script:BoxstarterPassword=$password
        $Boxstarter.RebootOk=$RebootOk
        Check-Chocolatey
        del "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -ErrorAction Ignore
        Stop-UpdateServices
        write-output "LocalRepo is at $localRepo"
        if(Test-Path "$localRepo\boxstarter.Helpers.*.nupkg") { $helperSrc = "$localRepo" }
        write-output "Checking for latest helper $(if($helperSrc){'locally'})"
        Chocolatey update boxstarter.helpers $helperSrc
        if(Get-Module boxstarter.helpers){Remove-Module boxstarter.helpers}
        $helperDir = (Get-ChildItem $env:ChocolateyInstall\lib\boxstarter.helpers*)
        if($helperDir.Count -gt 1){$helperDir = $helperDir[-1]}
        if($helperDir) { import-module $helperDir\boxstarter.helpers.psm1 }
        del $env:systemdrive\chocolatey\lib\$bootstrapPackage.* -recurse -force -ErrorAction Ignore
        if(test-path "$localRepo\$bootstrapPackage.*.nupkg"){
            $source = $localRepo
        } else {
            $source = "http://chocolatey.org/api/v2;http://www.myget.org/F/boxstarter/api/v2"
        }
        write-output "Installing Boxstarter package from $source"
        Chocolatey install $bootstrapPackage -source "$source" -force
    }
    finally{
        Cleanup-Boxstarter
    }
}
