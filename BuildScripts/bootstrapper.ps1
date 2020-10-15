# Attempt to set highest encryption available for SecurityProtocol.
# PowerShell will not set this by default (until maybe .NET 4.6.x). This
# will typically produce a message for PowerShell v2 (just an info
# message though)
try {
    # Set TLS 1.2 (3072) as that is the minimum required by Chocolatey.org.
    # Use integers because the enumeration value for TLS 1.2 won't exist
    # in .NET 4.0, even though they are addressable if .NET 4.5+ is
    # installed (.NET 4.5 is an in-place upgrade).
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
}
catch {
    Write-Output 'Unable to set PowerShell to use TLS 1.2. This is required for contacting Chocolatey as of 03 FEB 2020. https://chocolatey.org/blog/remove-support-for-old-tls-versions. If you see underlying connection closed or trust errors, you may need to do one or more of the following: (1) upgrade to .NET Framework 4.5+ and PowerShell v3+, (2) Call [System.Net.ServicePointManager]::SecurityProtocol = 3072; in PowerShell prior to attempting installation, (3) specify internal Chocolatey package location (set $env:chocolateyDownloadUrl prior to install or host the package internally), (4) use the Download + PowerShell method of install. See https://chocolatey.org/docs/installation for all install options.'
}

function Get-Boxstarter {
    Param(
        [string] $Version = "2.13.0",
        [switch] $Force
    )
    if(!(Test-Admin)) {
        $bootstrapperFile = ${function:Get-Boxstarter}.File
        if($bootstrapperFile) {
            Write-Host "User is not running with administrative rights. Attempting to elevate..."
            $command = "-ExecutionPolicy bypass -noexit -command . '$bootstrapperFile';Get-Boxstarter $($args)"
            Start-Process powershell -verb runas -argumentlist $command
        }
        else {
            Write-Host "User is not running with administrative rights.`nPlease open a PowerShell console as administrator and try again."
        }
        return
    }

    $badPolicy = $false
    @("Restricted", "AllSigned") | ? { $_ -eq (Get-ExecutionPolicy).ToString() } | % {
        Write-Host "Your current PowerShell Execution Policy is set to '$(Get-ExecutionPolicy)' and will prohibit boxstarter from operating properly."
        Write-Host "Please use Set-ExecutionPolicy to change the policy to RemoteSigned or Unrestricted."
        $badPolicy = $true
    }
    if($badPolicy) { return }

    Write-Output "Welcome to the Boxstarter Module installer!"
    if(Check-Chocolatey -Force:$Force){
        Write-Output "Chocolatey installed, Installing Boxstarter Modules."
        $chocoVersion  = "2.9.17"
        try {
            New-Object -TypeName Version -ArgumentList $chocoVersion.split('-')[0] | Out-Null
            $command = "cinst Boxstarter -y"
        }
        catch{
            # if there is no -v then its an older version with no -y
            $command = "cinst Boxstarter"
        }
        $command += " --version $version"
        Invoke-Expression $command
        Import-Module "$env:ProgramData\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1" -Force
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
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall\bin\choco.exe")){
        $message = "Chocolatey is going to be downloaded and installed on your machine. If you do not have the .NET Framework Version 4 or greater, that will also be downloaded and installed."
        Write-Host $message
        if($Force -OR (Confirm-Install)){
            $exitCode = Enable-Net40
            if($exitCode -ne 0) {
                Write-Warning ".net install returned $exitCode. You likely need to reboot your computer before proceeding with the install."
                return $false
            }
            try {
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
            catch {
                return $false
            }
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
        Get-HttpToFile "https://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe" "$env:temp\net45.exe"
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
