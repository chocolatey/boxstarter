Disable-UAC
Configure-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
Enable-Net35
if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
Enable-IIS-Win7
Enable-Telnet-Win7
Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:windir\system32\mstsc.exe"

Install-FromChocolatey console-devel
Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\console\console.exe"

Install-FromChocolatey sublimetext2
Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Sublime Text 2\sublime_text.exe"
Add-ExplorerMenuItem "sublime" "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe"
Add-ExplorerMenuItem "sublime" "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe" "folder"
Set-FileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
cmd /c assoc .=txtfile

Install-FromChocolatey skydrive
Install-FromChocolatey fiddler
Install-FromChocolatey posh-git-hg
Install-FromChocolatey git-credentials-winstore
Install-FromChocolatey tortoisehg

Install-FromChocolatey dotpeek
$dotPeekDir = (Get-ChildItem $env:systemdrive\chocolatey\lib\dotpeek* | select $_.last)
Set-FileAssociation ".dll" "$dotPeekDir\tools\dotPeek.exe"

Install-FromChocolatey Paint.net
Install-FromChocolatey VirtualBox
Install-FromChocolatey windirstat
Install-FromChocolatey sysinternals
Install-FromChocolatey evernote
Install-FromChocolatey AutoHotKey
Install-FromChocolatey NugetPackageExplorer
Install-FromChocolatey PowerGUI

Install-FromChocolatey googlechrome
Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Google\Chrome\Application\chrome.exe"

Install-FromChocolatey WindowsLiveWriter
Install-FromChocolatey WindowsLiveMesh
Install-FromChocolatey sqlexpressmanagementstudio -source webpi

Install-VS11-Beta
Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"
Install-ChocolateyPackage 'resharper' 'msi' '/quiet' 'http://download.jetbrains.com/resharper/ReSharperSetup.7.0.20.111.msi' 
Install-VsixSilently http://visualstudiogallery.msdn.microsoft.com/463c5987-f82b-46c8-a97e-b1cde42b9099/file/66837/1/xunit.runner.visualstudio.vsix xunit.runner.visualstudio.vsix, "11.0"
Install-FromChocolatey TestDriven.Net

Install-WindowsUpdatesWhenDone -GetUpdatesFromMS
