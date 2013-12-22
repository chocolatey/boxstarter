function Check-Chocolatey ([switch]$ShouldIntercept){
    Enable-Net40
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        Write-BoxstarterMessage "Chocolatey not instaled. Downloading and installing..."
        $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
        New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
        $config = Get-BoxstarterConfig
        $url=$config.ChocolateyPackage
        Enter-BoxstarterLogable {
            Get-HttpToFile $config.ChocolateyRepo "$env:temp\choco.ps1"
            $currentLogging=$Boxstarter.Suppresslogging
            if($VerbosePreference -eq "SilentlyContinue"){$Boxstarter.Suppresslogging=$true}
            . "$env:temp\choco.ps1"
            $Boxstarter.SuppressLogging = $currentLogging
        }
    }
    Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
    if(!$BoxstarterIntrercepting)
    {
        Write-BoxstarterMessage "Chocolatey installed, setting up interception of Chocolatey methods." -Verbose
        if($ShouldIntercept){Intercept-Chocolatey}
    }
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Get-IsRemote){
        if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
        if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
            if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
            Write-BoxstarterMessage "Downloading .net 4.5..."
            Get-HttpToFile "http://go.microsoft.com/?linkid=9816306" "$env:temp\net45.exe"
            Write-BoxstarterMessage "Installing .net 4.5..."
            Invoke-FromTask @"
Start-Process "$env:temp\net45.exe" -verb runas -wait -argumentList "/quiet /norestart /log $env:temp\net45.log"
"@
        }
    }
}

function Get-HttpToFile ($url, $file){
    Write-BoxstarterMessage "Downloading $url to $file" -Verbose
    Invoke-RetriableScript -RetryScript {
        if(Test-Path $args[1]){Remove-Item $args[1] -Force}
        $downloader=new-object net.webclient
        $wp=[system.net.WebProxy]::GetDefaultProxy()
        $wp.UseDefaultCredentials=$true
        $downloader.Proxy=$wp
        try {
            $downloader.DownloadFile($args[0], $args[1])
        }
        catch{
            if($VerbosePreference -eq "Continue"){
                Write-Error $($_.Exception | fl * -Force | Out-String)
            }
            throw $_
        }
    } $url $file
}
