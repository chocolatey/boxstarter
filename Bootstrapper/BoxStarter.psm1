# Boxstarter
# Version: $version$
# Changeset: $sha$

if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
$Boxstarter = @{ProgramFiles86="$programFiles86";ChocolateyBin="$env:systemdrive\chocolatey\bin"}
[xml]$configXml = Get-Content "$PSScriptRoot\BoxStarter.config"
$baseDir = (Split-Path -parent $PSScriptRoot)
$config = $configXml.config

function Invoke-BoxStarter{
    param(
      [string]$bootstrapPackage="default"
    )
    try{
        try{Start-Transcript -path $env:temp\boxstrter.log -Append}catch{$BoxStarterIsNotTranscribing=$true}
        Check-Chocolatey
        Stop-Service -Name wuauserv

        $localRepo = "$baseDir\BuildPackages"
        New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "$baseDir\BoxStarter.bat $bootstrapPackage"
        cinstm boxstarter.helpers
        cup boxstarter.helpers
        if(Get-Module boxstarter.helpers){Remove-Module boxstarter.helpers}
        $helperDir = (Get-ChildItem $env:ChocolateyInstall\lib\boxstarter.helpers* | select $_.last)
        import-module $helperDir\boxstarter.helpers.psm1
        del $env:systemdrive\chocolatey\lib\$bootstrapPackage.* -recurse -force
        ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" install $bootstrapPackage -source "$localRepo;http://chocolatey.org/api/v2/" -force

        Start-Service -Name wuauserv
        if(!$BoxStarterIsNotTranscribing){Stop-Transcript}
    }
    finally{
        if( !$Rebooting -and (Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat")) {
            remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
        }
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
Export-ModuleMember Invoke-BoxStarter
Export-ModuleMember -Variable $Boxstarter
