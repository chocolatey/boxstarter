param(
    [string]$sku="dev",
    [switch]$justFinishedUpdates
)
Start-Transcript -path $env:temp\transcript.log -Append
Stop-Service -Name wuauserv
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1
. $scriptPath\VsixInstallFunctions.ps1
Import-Module $scriptPath\PinnedApplications.psm1
if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }

if($justFinishedUpdates -eq $false){
    switch ($sku) {
        "Light" { #skuu for wife, kids or grandma
            Disable-UAC
            Configure-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
            Choc googlechrome 
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Google\Chrome\Application\chrome.exe"
        }
        "dev" { #super ultra beta dev sku
            Disable-UAC
            Configure-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
            Enable-Net35
            Enable-IIS-Win7
            Enable-Telnet-Win7
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:windir\system32\mstsc.exe"

            Choc console-devel
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\console\console.exe"

            Choc sublimetext2
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Add-ExplorerMenuItem "sublime" "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Add-ExplorerMenuItem "sublime" "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe" "folder"
            Set-FileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            cmd /c assoc .=txtfile
    
            Choc skydrive
            Choc fiddler
            Choc posh-git-hg
            Choc git-credentials-winstore
            Choc tortoisehg

            Choc dotpeek
            $dotPeekDir = (Get-ChildItem $env:systemdrive\chocolatey\lib\dotpeek* | select $_.last)
            Set-FileAssociation ".dll" "$dotPeekDir\tools\dotPeek.exe"

            Choc Paint.net
            Choc VirtualBox
            Choc windirstat
            Choc sysinternals
            Choc evernote
            Choc AutoHotKey
            Choc NugetPackageExplorer
            Choc PowerGUI

            Choc googlechrome
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Google\Chrome\Application\chrome.exe"

            Choc WindowsLiveWriter
            Choc WindowsLiveMesh
            Choc sqlexpressmanagementstudio -source webpi

            Install-VS11-Beta
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"
            Install-ChocolateyPackage 'resharper' 'msi' '/quiet' 'http://download.jetbrains.com/resharper/ReSharperSetup.7.0.20.111.msi' 
            InstallVsixSilently http://visualstudiogallery.msdn.microsoft.com/463c5987-f82b-46c8-a97e-b1cde42b9099/file/66837/1/xunit.runner.visualstudio.vsix xunit.runner.visualstudio.vsix, "11.0"
            Choc TestDriven.Net

            RunUpdatesWhenDone -GetUpdatesFromMS
        }

        "tfs-vm" {
            Disable-UAC
            Configure-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
            Disable-InternetExplorerESC

            \\tfsstor\Tools\Bootstraper\build.ps1
            $scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
            
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"
            
            Choc console-devel
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\console\console.exe"
            copy-item "$scriptPath\BuildPackages\console\console.xml" -Force $env:appdata\console\console.xml

            Choc sublimetext2
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Add-ExplorerMenuItem "sublime" "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            Add-ExplorerMenuItem "sublime" "Open with Sublime Text 2" "$env:programfiles\Sublime Text 2\sublime_text.exe" "folder"
            Set-FileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
            cmd /c assoc .=txtfile
            copy-item "$scriptPath\BuildPackages\sublime\*" -force -Recurse "$env:appdata\sublime text 2\"

            Choc AutoHotKey
            set-content "$env:appdata\Microsoft\Windows\Start Menu\Programs\startup\AutoScript.ahk" -Force -value @"
^+C::
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
            RunUpdatesWhenDone         
        }
    }
}

if($global:RunUpdatesWhenDone -or $justFinishedUpdates){Force-Windows-Update $global:GetUpdatesFromMSWhenDone}
Start-Service -Name wuauserv
Stop-Transcript

