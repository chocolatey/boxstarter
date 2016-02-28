function Get-Boxstarter {
    Param(
        [switch] $Force
    )
    if(!(Test-Admin)) {
        Write-Host "User is not running with administrative rights. Attempting to elevate..."
        $command = "-ExecutionPolicy bypass -noexit -command . '$(${function:Get-Boxstarter}.File)';Get-Boxstarter $($args)"
        Start-Process powershell -verb runas -argumentlist $command
        return
    }

    Write-Output "Welcome to the Boxstarter Module installer!"
    if(Check-Chocolatey -Force:$Force){
        Write-Output "Chocolatey installed, Installing Boxstarter Modules."
        $version = choco -v
        try {
            New-Object -TypeName Version -ArgumentList $version.split('-')[0] | Out-Null
            $command = "cinst Boxstarter -y"
        }
        catch{
            # if there is no -v then its an older version with no -y
            $command = "cinst Boxstarter"
        }
        $command += " -version 2.6.41"
        Invoke-Expression $command
        $Message = "Boxstarter Module Installer completed"
    }
    else {
        $Message = "Did not detect Chocolatey and unable to install. Installation of Boxstarter has been aborted."
    }
    if($Force) {
        Write-Host $Message
    }
    else {
        Read-Host $Message
    }
}

function Check-Chocolatey {
    Param(
        [switch] $Force
    )
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        $message = "Chocolatey is going to be downloaded and installed on your machine. If you do not have the .NET Framework Version 4 or greater, that will also be downloaded and installed."
        Write-Host $message
        if($Force -OR (Confirm-Install)){
            $exitCode = Enable-Net40
            if($exitCode -ne 0) {
                Write-Warning ".net install returned $exitCode. You likely need to reboot your computer before proceeding with the install."
                return $false
            }
            $env:ChocolateyInstall = "$env:programdata\chocolatey"
            New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
            $url="https://chocolatey.org/api/v2/package/chocolatey/"
            $wc=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $wc.Proxy=$wp
            iex ($wc.DownloadString("https://chocolatey.org/install.ps1"))
            $env:path="$env:path;$env:ChocolateyInstall\bin"
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
        Write-Host "Downloading .net 4.5..."
        Get-HttpToFile "http://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe" "$env:temp\net45.exe"
        Write-Host "Installing .net 4.5..."
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "$env:temp\net45.exe"
        $pinfo.Verb="runas"
        $pinfo.Arguments = "/quiet /norestart /log $env:temp\net45.log"
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $p.WaitForExit()
        $e = $p.ExitCode
        if($e -ne 0){
            Write-Host "Installer exited with $e"
        }
        return $e
    }
    return 0
}

function Get-HttpToFile ($url, $file){
    Write-Verbose "Downloading $url to $file"
    if(Test-Path $file){Remove-Item $file -Force}
    $downloader=new-object net.webclient
    $wp=[system.net.WebProxy]::GetDefaultProxy()
    $wp.UseDefaultCredentials=$true
    $downloader.Proxy=$wp
    try {
        $downloader.DownloadFile($url, $file)
    }
    catch{
        if($VerbosePreference -eq "Continue"){
            Write-Error $($_.Exception | fl * -Force | Out-String)
        }
        throw $_
    }
}

function Confirm-Install {
    $caption = "Installing Chocolatey"
    $message = "Do you want to proceed?"
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
