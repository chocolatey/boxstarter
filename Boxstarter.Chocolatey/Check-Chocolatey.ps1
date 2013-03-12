function Check-Chocolatey ([switch]$ShouldIntercept){
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        Write-BoxstarterMessage "Chocolatey not instaled. Boxstarter will download and install."
        $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
        New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
        $url=$Boxstarter.config.ChocolateyPackage
        Enter-BoxstarterLogable {
            iex ((new-object net.webclient).DownloadString($Boxstarter.config.ChocolateyRepo))
            Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
            Enable-Net40
        }
    }
    Write-BoxstarterMessage "Chocoltey installed, seting up interception of Chocolatey methods."
    if($ShouldIntercept){Intercept-Chocolatey}
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        $session=Start-TimedSection "Download and install .NET 4.0 Framework"
        $env:chocolateyPackageFolder="$env:temp\chocolatey\webcmd"
        Install-ChocolateyZipPackage 'webcmd' 'http://www.iis.net/community/files/webpi/webpicmdline_anycpu.zip' $env:temp
        .$env:temp\WebpiCmdLine.exe /products: NetFramework4 /accepteula
        Stop-TimedSection $session
    }
}