function Get-Boxstarter ([switch]$Force){
    Write-Output "Welcome to the Boxstarter Module installer!"
    if(Test-Chocolatey -Force:$Force){    
        Write-Output "Chocoltey installed, Installing Boxstarter Modules."
        cinst Boxstarter.Virtualization -version 1.1.35
        $Message = "Boxstarter Module Installer completed"
    }
    else {
        $Message = "Did not detect Chocolatey and unable to install. Installation of Boxstarter has been aborted."
    }
    if(!Force){ Read-Host $Message }
}

function Test-Chocolatey ([switch]$Force){
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        if($Force -or Confirm-Install){
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
            Enable-DotNet40
        }
        else{
            return $false
        }
    }
    return $true
}

function Test-64Bit {  [IntPtr]::Size -eq 8  }

function Enable-DotNet40 {
    if(Test-64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        Write-Output "Download and install .NET 4.0 Framework"
        $env:chocolateyPackageFolder="$env:temp\chocolatey\webcmd"
        Install-ChocolateyZipPackage 'webcmd' 'http://www.iis.net/community/files/webpi/webpicmdline_anycpu.zip' $env:temp
        Write-Output "The .Net 4 framework is about to be installed. This may take several minutes."
        Remove-Module chocolateyInstaller
        if(Test-Admin){
            ."$env:temp\WebpiCmdLine.exe" /products: NetFramework4 /SuppressReboot /accepteula
        }
        else{
            Write-Output "Installing .NET 4 in a separate window. Boxstarter instalation will complete when it finishes..."
            $p = Start-Process "$env:temp\WebpiCmdLine.exe" -verb runas -ArgumentList "/products: NetFramework4 /SuppressReboot /accepteula" -passthru
            $p.WaitForExit()            
        }
    }
}

function Confirm-Install {
    $caption = "Installing Chocoltey"
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

