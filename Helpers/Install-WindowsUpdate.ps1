function Install-WindowsUpdate {
<#
.SYNOPSIS
Downloads and installs updates via Windows Update

.DESCRIPTION
This uses the windows update servise to search, download and install updates. By default, only critical updates are included and a reboot will be induced if required.

.PARAMETER GetUpdatesFromMS
If this switch is set, the default windows update server, if any, is bypassed and windows update requests go to the public Microsoft Windows update service.

.PARAMETER AcceptEula
If any update requires a eula acceptance, setting this switch will accept the eula and allow the update to be installed.

.PARAMETER SuppressReboots
Setting this switch will suppress a reboot in the event that any update requires one.

.PARAMETER Criteria
The criteria used for searching updates. The default criteria is "BrowseOnly=0 and IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'" which is effectively just critical updates.

.LINK
http://boxstarter.codeplex.com

#>    
    param(
        [switch]$getUpdatesFromMS, 
        [switch]$acceptEula, 
        [switch]$SuppressReboots,
        [string]$criteria="IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'"
    )
    if($getUpdatesFromMS) {
        $auPath="HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if(Test-Path $auPath) {
            $origAUVal=(Get-ItemProperty -Path $auPath -Name UseWuServer -ErrorAction SilentlyContinue)
            Set-ItemProperty -Path $auPath -Name UseWuServer -Value 0 -ErrorAction SilentlyContinue
        }
    }
    try{
        Write-Output "Checking for updates..."
        $updateSession =new-object -comobject "Microsoft.Update.Session"
        $updatesToDownload =new-Object -com "Microsoft.Update.UpdateColl"
        $updatesToInstall =new-object -com "Microsoft.Update.UpdateColl"
        $Downloader =$updateSession.CreateUpdateDownloader()
        $Installer =$updateSession.CreateUpdateInstaller()
        $Searcher =$updatesession.CreateUpdateSearcher()
        $Result = $Searcher.Search($criteria)

        If ($Result.updates.count -ne 0)
        {
            Write-Output "$($Result.updates.count) Updates found"
            foreach($update in $result.updates) {
                if ($update.isDownloaded -ne "true") {
                    Write-Output " * Adding $($update.title) to list of updates to download"
                    $updatesToDownload.add($update) | Out-Null
                }
                else {Write-Output " * $($update.title) already downloaded"}
            }

            If ($updatesToDownload.Count -gt 0) {
                Write-Output "Beginning to download $($updatesToDownload.Count) updates"
                $Downloader.Updates = $updatesToDownload
                $Downloader.Download()
            }
            
            Write-Output "Downloading complete"
            foreach($update in $result.updates) {
                if(!($update.EulaAccepted) -and $acceptEula){
                    $update.AcceptEula()
                }
                $updatesToinstall.add($update) | Out-Null
            }

            Write-Output "Beginning to install"
            $Installer.updates = $UpdatesToInstall
            $result = $Installer.Install()

            if($result.rebootRequired) {
                if($SuppressReboots) {
                    Write-Output "A Restart is Required."
                } else {
                    $Rebooting=$true
                    Write-Output "Restart Required. Restarting now..."
                    if(get-module Boxstarter) {
                        return Invoke-Reboot
                    } else {
                        Restart-Computer -force
                    }
                }
            }
            Write-Output "All updates installed"
            return $result
        }
        else{Write-Output "There is no update applicable to this machine"}    
    }
    finally {
        if($origAUVal){
            Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU -Name UseWuServer -Value $origAUVal -ErrorAction SilentlyContinue
        }
    }
}