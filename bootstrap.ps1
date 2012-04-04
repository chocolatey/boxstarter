param(
    [string]$sku="Light",
    [switch]$justFinishedUpdates
)

$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1

function Setup-Choc-Packages {
    Copy-Item $scriptPath\PackageAssets\console.xml $env:appdata\Console
    Copy-Item $scriptPath\PackageAssets\AutoScript.ahk "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
    New Item  (Join-Path $env:appdata "Sublime Text 2\Installed Packages") -type directory
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\Package Control.sublime-package") (Join-Path $env:appdata "Sublime Text 2\Installed Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\AAAPackageDev") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\PowerShell") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\PowerShellUtils") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name Path  -Value "$env:path;$env:programfiles\Google\Chrome\Application;$env:programfiles\Sublime Text 2;$env:programfiles\console"
}

if($justFinishedUpdates -eq $false){
    Import-Module $scriptPath\PinnedApplications.psm1
    Disable-UAC
    iex ((new-object net.webclient).DownloadString('http://bit.ly/psChocInstall'))
    if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }

    switch ($sku) {
        "Light" { #sku for wife, kids or grandma
            Choc googlechrome 
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Google\Chrome\Application\chrome.exe"
        }
        "dev" { #super ultra beta dev sku
            Choc googlechrome
            Choc console-devel
            Choc sublimetext2
            Choc fiddler
            Choc msysgit
            Choc poshgit 
            Choc hg
            Choc dotpeek
            Choc Paint.net
            Choc VirtualBox
            Choc windirstat
            Choc sysinternals
            Choc evernote
            Choc AutoHotKey
            Enable-Telnet-Win7
            Enable-IIS-Win7
            Install-SqlExpress
            Install-VS11-Beta
            Add-ExplorerMenuItem "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Google\Chrome\Application\chrome.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:windir\system32\mstsc.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\console\console.exe"
            $dotPeekDir = (Get-ChildItem $env:systemdrive\chocolatey\lib\dotpeek* | select $_.last)
            Set-FileAssociation ".dll" "$dotPeekDir\tools\dotPeek.exe"
            Set-FileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            cmd /c assoc .=txtfile
        }
    }
}

Force-Windows-update
if( Test-Path $scriptPath\bootstrap\post-bootstrap.ps1) {
    Invoke-Expression "$scriptPath\post-bootstrap.ps1 $args"
}

