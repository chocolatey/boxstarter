function Check-Chocolatey ([switch]$ShouldIntercept){
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        Write-BoxstarterMessage "Chocolatey not instaled. Downloading and installing..."
        $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
        New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
        $config = Get-BoxstarterConfig
        $url=$config.ChocolateyPackage
        Enter-BoxstarterLogable {
            $wc=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $wc.Proxy=$wp
            $currentLogging=$Boxstarter.Suppresslogging
            if($VerbosePreference -eq "SilentlyContinue"){$Boxstarter.Suppresslogging=$true}
            iex ($wc.DownloadString($config.ChocolateyRepo)) | Out-Null
            $Boxstarter.SuppressLogging = $currentLogging
        }
    }
    Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
    Enable-Net40
    if(!$BoxstarterIntrercepting)
    {
        Write-BoxstarterMessage "Chocolatey installed, setting up interception of Chocolatey methods." -Verbose
        if($ShouldIntercept){Intercept-Chocolatey}
    }
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        $session=Start-TimedSection "Download and install of .NET 4.5 Framework. This may take several minutes..."
        if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
        $currentLogging=$Boxstarter.Suppresslogging
        if($VerbosePreference -eq "SilentlyContinue"){$Boxstarter.Suppresslogging=$true}
        Install-ChocolateyPackage 'dotnet45' 'exe' "/Passive /NoRestart /Log $env:temp\net45.log" 'http://go.microsoft.com/?linkid=9816306' -validExitCodes @(0,3010)
        $Boxstarter.SuppressLogging = $currentLogging
        Stop-TimedSection $session
    }
}
