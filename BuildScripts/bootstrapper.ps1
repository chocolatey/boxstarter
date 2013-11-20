function Get-Boxstarter {
    Write-Output "Welcome to the Boxstarter Module installer!"
    if(Check-Chocolatey ){    
        Write-Output "Chocoltey installed, Installing Boxstarter Modules."
        cinst Boxstarter -version 2.0.25
        $Message = "Boxstarter Module Installer completed"
    }
    else {
        $Message = "Did not detect Chocolatey and unable to install. Installation of Boxstarter has been aborted."
    }
    Read-Host $Message
}

function Check-Chocolatey {
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        if(Confirm-Install){
            $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
            New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
            $url="http://chocolatey.org/api/v2/package/chocolatey/"
            $wc=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $wc.Proxy=$wp
            iex ($wc.DownloadString("http://chocolatey.org/install.ps1"))            
            Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
            $env:path="$env:path;$env:systemdrive\chocolatey\bin"
            Enable-Net40
        }
        else{
            return $false
        }
    }
    return $true
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        Write-Output "Download and install .NET 4.0 Framework"
        $env:chocolateyPackageFolder="$env:temp\chocolatey\webcmd"
        Install-ChocolateyZipPackage 'webcmd' 'http://www.iis.net/community/files/webpi/webpicmdline_anycpu.zip' $env:temp
        Write-Host "The .Net 4 framework is about to be installed. This may take several minutes."
        Remove-Module chocolateyInstaller
        if(Test-Admin){
            ."$env:temp\WebpiCmdLine.exe" /products: NetFramework4 /SuppressReboot /accepteula
        }
        else{
            Write-host "Installing .NET 4 in a separate window. Boxstarter instalation will complete when it finishes..."
            $p = Start-Process "$env:temp\WebpiCmdLine.exe" -verb runas -ArgumentList "/products: NetFramework4 /SuppressReboot /accepteula" -passthru
            $p.WaitForExit()            
        }
    }
}

function Confirm-Install {
    $caption = "Installing Chocolatey"
    $message = "Chocolatey is going to be downloaded and installed on your machine. If you do not have the .NET Framework Version 4, that will aldo be downloaded and installed. Do you want to proceed?"
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    switch ($answer){
        0 {return $true; break}
        1 {return $false; break}
    }    
}

function Test-Admin {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

