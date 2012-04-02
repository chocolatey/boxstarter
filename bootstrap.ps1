param(
    [string]$sku="Light"
)

$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1

function Choc([string] $package) {
    .$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd install $package
}
function Setup-Choc-Packages {
$consolePath = Get-Item -path $env:systemdrive\chocolatey\lib\Console2*\bin
    Copy-Item $scriptPath\PackageAssets\console.xml $consolePath
    New Item  (Join-Path $env:appdata "Sublime Text 2\Installed Packages") -type directory
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\Package Control.sublime-package") (Join-Path $env:appdata "Sublime Text 2\Installed Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\AAAPackageDev") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\PowerShell") (Join-Path $env:appdata "Sublime Text 2\Packages")
    Copy-Item (Join-Path $scriptPath "PackageAssets\SublimePackages\PowerShellUtils") (Join-Path $env:appdata "Sublime Text 2\Packages")
    setx PATH "$env:path;$env:localappdata\Google\Chrome\Application;$env:programfiles\Sublime Text 2" -m
}
Disable-UAC
iex ((new-object net.webclient).DownloadString('http://bit.ly/psChocInstall'))

switch ($sku) {
    "Light" { Choc googlechrome }
    "dev" {
        Choc console2
        Choc sublimetext2
        Choc fiddler
        Choc mysgit
        Choc poshgit 
        Choc hg
        Choc dotpeek
        Choc Paint.net
        Choc VirtualBox
        Enable-Telnet-Win7
        Enable-IIS-Win7
        Install-VS11-Beta
    }
}

if( Test-Path $scriptPath\bootstrap\post-bootstrap.ps1) {
    Invoke-Expression "$scriptPath\post-bootstrap.ps1 $args"
}

