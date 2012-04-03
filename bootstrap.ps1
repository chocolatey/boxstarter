param(
    [string]$sku="Light",
    [switch]$justFinishedUpdates
)

$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1

function Choc([string] $package) {
    .$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd install $package
}
function Setup-Choc-Packages {
    Copy-Item $scriptPath\PackageAssets\console.xml $env:appdata\Console
    New Item  (Join-Path $env:appdata "Sublime Text 2\Installed Packages") -type directory
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\Package Control.sublime-package") (Join-Path $env:appdata "Sublime Text 2\Installed Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\AAAPackageDev") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\PowerShell") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\PowerShellUtils") (Join-Path $env:appdata "Sublime Text 2\Packages")
    setx PATH "$env:path;$env:programfiles\Google\Chrome\Application;$env:programfiles\Sublime Text 2" -m
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
            Enable-Telnet-Win7
            Enable-IIS-Win7
            Install-VS11-Beta
            Add-ExplorerMenuItem "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Google\Chrome\Application\chrome.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:windir\system32\mstsc.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\console\console.exe"            
        }
    }
}

Force-Windows-update
if( Test-Path $scriptPath\bootstrap\post-bootstrap.ps1) {
    Invoke-Expression "$scriptPath\post-bootstrap.ps1 $args"
}

