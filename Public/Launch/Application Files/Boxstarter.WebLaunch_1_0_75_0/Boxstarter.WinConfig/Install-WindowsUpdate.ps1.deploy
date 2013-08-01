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
The criteria used for searching updates. The default criteria is "IsHidden=0 and IsInstalled=0 and Type='Software'" which is effectively just critical updates.

.LINK
http://boxstarter.codeplex.com

#>    
    param(
        [switch]$getUpdatesFromMS, 
        [switch]$acceptEula, 
        [switch]$SuppressReboots,
        [string]$criteria="IsHidden=0 and IsInstalled=0 and Type='Software'"
    )
    if($getUpdatesFromMS) {
        $auPath="HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if(Test-Path $auPath) {
            $origAUVal=(Get-ItemProperty -Path $auPath -Name UseWuServer -ErrorAction SilentlyContinue)
            Set-ItemProperty -Path $auPath -Name UseWuServer -Value 0 -ErrorAction SilentlyContinue
        }
    }
    try{
        $searchSession=Start-TimedSection "Checking for updates..."
        $updateSession =new-object -comobject "Microsoft.Update.Session"
        $updatesToDownload =new-Object -com "Microsoft.Update.UpdateColl"
        $updatesToInstall =new-object -com "Microsoft.Update.UpdateColl"
        $Downloader =$updateSession.CreateUpdateDownloader()
        $Installer =$updateSession.CreateUpdateInstaller()
        $Searcher =$updatesession.CreateUpdateSearcher()
        $Result = $Searcher.Search($criteria)
        Stop-TimedSection $searchSession

        If ($Result.updates.count -ne 0)
        {
            Out-BoxstarterLog "$($Result.updates.count) Updates found"
            foreach($update in $result.updates) {
                if ($update.isDownloaded -ne "true" -and ($update.InstallationBehavior.CanRequestUserInput -eq $false )) {
                    Out-BoxstarterLog " * Adding $($update.title) to list of updates to download"
                    $updatesToDownload.add($update) | Out-Null
                }
                else {Out-BoxstarterLog " * $($update.title) already downloaded"}
            }

            If ($updatesToDownload.Count -gt 0) {
                $downloadSession=Start-TimedSection "Downloading $($updatesToDownload.Count) updates"
                $Downloader.Updates = $updatesToDownload
                $Downloader.Download() | Out-Null
                Stop-TimedSection $downloadSession
            }
            
            foreach($update in $result.updates) {
                if(!($update.EulaAccepted) -and $acceptEula){
                    $update.AcceptEula()
                }
                $updatesToinstall.add($update) | Out-Null
            }

            $installSession=Start-TimedSection "Installing Updates"
            Out-BoxstarterLog "This may take several minutes..."
                $Installer.updates = $UpdatesToInstall
                try { $result = $Installer.Install() } catch {
                    # Check for WU_E_INSTALL_NOT_ALLOWED  
                    if($_.Exception.HResult -eq -2146233087) {
                        Out-BoxstarterLog "You either do not have rights or there is a pending reboot blocking the install."
                        Out-BoxstarterLog "If you are using the Bootstrapper or Chocolatey module, try using:"
                        Out-BoxstarterLog "if(Test-PendingReboot){Invoke-Reboot}"
                        Out-BoxstarterLog "This will perform a reboot if reboots are pending."
                    }
                    throw
                }

                if($result.rebootRequired) {
                    if($SuppressReboots) {
                        Out-BoxstarterLog "A Restart is Required."
                    } else {
                        $Rebooting=$true
                        Write-BoxstarterMessage "Restart Required. Restarting now..."
                        Stop-TimedSection $installSession
                        if(test-path function:\Invoke-Reboot) {
                            return Invoke-Reboot
                        } else {
                            Restart-Computer -force
                        }
                    }
                }
            Stop-TimedSection $installSession
        }
        else{Write-BoxstarterMessage "There is no update applicable to this machine"}    
    }
    finally {
        if($origAUVal){
            Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU -Name UseWuServer -Value $origAUVal -ErrorAction SilentlyContinue
        }
    }
}