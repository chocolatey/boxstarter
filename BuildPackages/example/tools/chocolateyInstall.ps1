Disable-UAC
Install-WindowsUpdate -AcceptEula

Move-LibraryDirectory "Personal" "$env:UserProfile\skydrive\documents"
Set-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
Set-TaskbarSmall
Enable-RemoteDesktop

cinstm VisualStudio2012Ultimate
cinstm fiddler
cinstm mssqlserver2012express
cinstm office2013ProPlusPreview

cinstm git-credential-winstore
cinstm console-devel
cinstm sublimetext2
cinstm skydrive
cinstm poshgit
cinstm dotpeek
cinstm AutoHotKey_L
cinstm googlechrome
cinstm Paint.net
cinstm VirtualBox
cinstm windirstat
cinstm sysinternals
cinstm evernote
cinstm NugetPackageExplorer
cinstm WindowsLiveWriter
cinstm resharper
cinstm winrar
cinstm firefox
cinstm windbg
cinstm qttabbar
cinstm testdriven.net
cinstm adobereader

cinst IIS-WebServerRole -source windowsfeatures
cinst IIS-HttpCompressionDynamic -source windowsfeatures
cinst IIS-ManagementScriptingTools -source windowsfeatures
cinst IIS-WindowsAuthentication -source windowsfeatures
cinst TelnetClient -source windowsFeatures

$sublimeDir = "$env:programfiles\Sublime Text 2"

Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\mstsc.exe"
Install-ChocolateyPinnedTaskBarItem "$env:programfiles\console\console.exe"
Install-ChocolateyPinnedTaskBarItem "$sublimeDir\sublime_text.exe"
Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Google\Chrome\Application\chrome.exe"
Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"

Install-ChocolateyFileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
Install-ChocolateyFileAssociation ".dll" "$($Boxstarter.ChocolateyBin)\dotPeek.bat"

mkdir "$sublimeDir\data"
copy-item (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'sublime\*') -Force -Recurse "$sublimeDir\data"
move-item "$sublimeDir\data\Pristine Packages\*" -Force "$sublimeDir\Pristine Packages"
copy-item (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'console.xml') -Force $env:appdata\console\console.xml

Install-ChocolateyVsixPackage xunit http://visualstudiogallery.msdn.microsoft.com/463c5987-f82b-46c8-a97e-b1cde42b9099/file/66837/1/xunit.runner.visualstudio.vsix
Install-ChocolateyVsixPackage autowrocktestable http://visualstudiogallery.msdn.microsoft.com/ea3a37c9-1c76-4628-803e-b10a109e7943/file/73131/1/AutoWrockTestable.vsix
Install-ChocolateyVsixPackage vscommands http://visualstudiogallery.msdn.microsoft.com/a83505c6-77b3-44a6-b53b-73d77cba84c8/file/74740/18/SquaredInfinity.VSCommands.VS11.vsix

$ahk = "$env:appdata\Microsoft\Windows\Start Menu\Programs\startup\AutoScript.ahk"
set-content $ahk -Force -value @"
^+C::
#SingleInstance force
IfWinExist Console
{
    WinActivate
}
else
{
    Run Console
    WinWait Console
    WinActivate
}
"@
.$ahk