param(
    [string]$sku="dev",
    [switch]$justFinishedUpdates
)

$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1

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
            Enable-Net35-Win7
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
    
            Choc fiddler
            Choc posh-git-hg
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

            Choc googlechrome
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$env:programfiles\Google\Chrome\Application\chrome.exe"

            Choc WindowsLiveWriter
            Choc WindowsLiveMesh
            Choc sqlexpressmanagementstudio -source webpi
            Install-VS11-Beta
            Set-PinnedApplication -Action PinToTaskbar -FilePath "$programFiles86\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"
        }
    }
}

Force-Windows-update
if( Test-Path $scriptPath\bootstrap\post-bootstrap.ps1) {
    Invoke-Expression "$scriptPath\post-bootstrap.ps1 $args"
}

