Disable-UAC
Set-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
Enable-RemoteDesktop

cinstm console-devel
cinstm sublimetext2
cinst TelnetClient -source windowsFeatures

$sublimeDir = "$env:programfiles\Sublime Text 2"

Install-ChocolateyPinnedTaskBarItem "$env:programfiles\console\console.exe"
Install-ChocolateyPinnedTaskBarItem "$sublimeDir\sublime_text.exe"

Install-ChocolateyFileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"

mkdir "$sublimeDir\data"
copy-item (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'sublime\*') -Force -Recurse "$sublimeDir\data"
move-item "$sublimeDir\data\Pristine Packages\*" -Force "$sublimeDir\Pristine Packages"
copy-item (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'console.xml') -Force $env:appdata\console\console.xml