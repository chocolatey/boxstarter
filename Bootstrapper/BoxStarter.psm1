# Boxstarter
# Version: $version$
# Changeset: $sha$

if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
$Boxstarter = @{ProgramFiles86="$programFiles86";ChocolateyBin="$env:systemdrive\chocolatey\bin";Log="$env:temp\boxstarter.log"}
[xml]$configXml = Get-Content "$PSScriptRoot\BoxStarter.config"
$baseDir = (Split-Path -parent $PSScriptRoot)
$config = $configXml.config

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
    param(
      [string]$bootstrapPackage="default",
      [string]$localRepo="$baseDir\BuildPackages"
    )
    try{
        Check-Chocolatey
        del "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -ErrorAction Ignore
        Stop-UpdateServices
        write-output "LocalRepo is at $localRepo"
        if(Test-Path "$localRepo\boxstarter.Helpers.*.nupkg") { $helperSrc = "$localRepo" }
        write-output "Checking for latest helper $(if($helperSrc){'locally'})"
        ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" update boxstarter.helpers $helperSrc
        if(Get-Module boxstarter.helpers){Remove-Module boxstarter.helpers}
        $helperDir = (Get-ChildItem $env:ChocolateyInstall\lib\boxstarter.helpers*)
        if($helperDir.Count -gt 1){$helperDir = $helperDir[-1]}
        import-module $helperDir\boxstarter.helpers.psm1
        del $env:systemdrive\chocolatey\lib\$bootstrapPackage.* -recurse -force -ErrorAction Ignore
        if(test-path "$localRepo\$bootstrapPackage.*.nupkg"){
            $source = $localRepo
        } else {
            $source = "http://chocolatey.org/api/v2;http://www.myget.org/F/boxstarter/api/v2"
        }
        write-output "Installing Boxstarter package from $source"
        ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" install $bootstrapPackage -source "$source" -force
    }
    finally{
        Cleanup
    }
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        Install-ChocolateyZipPackage 'webcmd' 'http://www.iis.net/community/files/webpi/webpicmdline_anycpu.zip' $env:temp
        .$env:temp\WebpiCmdLine.exe /products: NetFramework4 /accepteula
    }
}
function Check-Chocolatey{
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
        New-Item $env:ChocolateyInstall -Force -type directory
        $url=$config.ChocolateyPackage
        iex ((new-object net.webclient).DownloadString($config.ChocolateyRepo))
        Enable-Net40
    }
    Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
}

function Stop-UpdateServices {
    Stop-Service -Name wuauserv
    Stop-CCMEXEC
}

function Start-UpdateServices {
    Start-Service -Name wuauserv
    Start-CCMEXEC
}

function Stop-CCMEXEC {
    $ccm = (get-service -include CCMEXEC)
    if($ccm) {
        set-service CCMEXEC -startuptype disabled
        do {
            if($ccm.CanStop) { 
                Write-Output "Stopping Configuration Manager"
                Stop-Service CCMEXEC
                return
            }
            Write-Output "Waiting for Computer Configuration Manager to stop..."
            sleep 10
        } while (-not ($ccm.CanStop) -and ($i++ -lt 5))
    }
}

function Start-CCMEXEC {
    $ccm = get-service -include CCMEXEC
    if($ccm) {
        set-service CCMEXEC -startuptype automatic
        Start-Service CCMEXEC
    }
}

function Cleanup {
  if(!$boxstarterRebooting) { 
    if( Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat") {
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    }
    $winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $winLogonKey -Name "DefaultUserName" -ErrorAction Ignore
    Remove-ItemProperty -Path $winLogonKey -Name "DefaultDomainName" -ErrorAction Ignore
    Remove-ItemProperty -Path $winLogonKey -Name "DefaultPassword" -ErrorAction Ignore
    Remove-ItemProperty -Path $winLogonKey -Name "AutoAdminLogon" -ErrorAction Ignore
    Start-UpdateServices
  } 
}

Export-ModuleMember Invoke-BoxStarter, Test-PendingReboot, Invoke-Reboot, cinst, cup, cinstm, chocolatey
Export-ModuleMember -Variable Boxstarter
