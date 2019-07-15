function Install-WindowsUpdate {
<#
.SYNOPSIS
Downloads and installs updates via Windows Update

.DESCRIPTION
This uses the windows update service to search, download and install updates. By default, only critical updates are included and a reboot will be induced if required.

.PARAMETER GetUpdatesFromMS
If this switch is set, the default windows update server, if any, is bypassed and windows update requests go to the public Microsoft Windows update service.

.PARAMETER AcceptEula
If any update requires a Eula acceptance, setting this switch will accept the Eula and allow the update to be installed.

.PARAMETER SuppressReboots
Setting this switch will suppress a reboot in the event that any update requires one.

.PARAMETER Criteria
The criteria used for searching updates. The default criteria is "IsHidden=0 and IsInstalled=0 and Type='Software'" which is effectively just critical updates.

.LINK
https://boxstarter.org

#>
    param(
        [switch]$getUpdatesFromMS,
        [switch]$acceptEula,
        [switch]$SuppressReboots,
        [string]$criteria="IsHidden=0 and IsInstalled=0 and Type='Software' and BrowseOnly=0"
    )

    if(Get-IsRemote){
        Invoke-FromTask @"
Import-Module $($boxstarter.BaseDir)\boxstarter.WinConfig\Boxstarter.Winconfig.psd1
Install-WindowsUpdate -GetUpdatesFromMS:`$$GetUpdatesFromMS -AcceptEula:`$$AcceptEula -SuppressReboots -Criteria "$Criteria"
"@ -IdleTimeout 0 -TotalTimeout 0
        if(Test-PendingReboot){
            Invoke-Reboot
        }
        return
    }

    try{
        $searchSession=Start-TimedSection "Checking for updates..."
        $updateSession =new-object -comobject "Microsoft.Update.Session"
        $Downloader =$updateSession.CreateUpdateDownloader()
        $Installer =$updateSession.CreateUpdateInstaller()
        $Searcher =$updatesession.CreateUpdateSearcher()
        if($getUpdatesFromMS) {
            $Searcher.ServerSelection = 2 #2 is the Const for the Windows Update server
        }
        $wus=Get-WmiObject -Class Win32_Service -Filter "Name='wuauserv'"
        $origStatus=$wus.State
        $origStartupType=$wus.StartMode
        Write-BoxstarterMessage "Update service is in the $origStatus state and its startup type is $origStartupType" -verbose
        if($origStartupType -eq "Auto"){
            $origStartupType = "Automatic"
        }
        if($origStatus -eq "Stopped"){
            if($origStartupType -eq "Disabled"){
                Set-Service wuauserv -StartupType Automatic
            }
            Out-BoxstarterLog "Starting windows update service" -verbose
            Start-Service -Name wuauserv
        }
        else {
            # Restart in case updates are running in the background
            Out-BoxstarterLog "Restarting windows update service" -verbose
            Remove-BoxstarterError { Restart-Service -Name wuauserv -Force -WarningAction SilentlyContinue }
        }

        $Result = $Searcher.Search($criteria)
        Stop-TimedSection $searchSession
        $totalUpdates = $Result.updates.count

        If ($totalUpdates -ne 0)
        {
            Out-BoxstarterLog "$($Result.updates.count) Updates found"
            $currentCount = 0
            foreach($update in $result.updates) {
                ++$currentCount
                if(!($update.EulaAccepted)){
                    if($acceptEula) {
                        $update.AcceptEula()
                    }
                    else {
                        Out-BoxstarterLog " * $($update.title) has a user agreement that must be accepted. Call Install-WindowsUpdate with the -AcceptEula parameter to accept all user agreements. This update will be ignored."
                        continue
                    }
                }

                $Result= $null
                if ($update.InstallationBehavior.CanRequestUserInput -eq $false ) {
                    Download-Update $update
                    $result = install-Update $update $currentCount $totalUpdates
                }
                else {
                    Out-BoxstarterLog " * $($update.title) Requires user input and will not be downloaded"
                }
            }

            if($result -ne $null -and $result.rebootRequired) {
                if($SuppressReboots) {
                    Out-BoxstarterLog "A Restart is Required."
                } else {
                    $Rebooting=$true
                    Out-BoxstarterLog "Restart Required. Restarting now..."
                    Stop-TimedSection $installSession
                    if(test-path function:\Invoke-Reboot) {
                        return Invoke-Reboot
                    } else {
                        Restart-Computer -force
                    }
                }
            }
        }
        else{Out-BoxstarterLog "There is no update applicable to this machine"}
    }
    catch {
        Out-BoxstarterLog "There were problems installing updates: $($_.ToString())"
        throw
    }
    finally {
        if($origAUVal){
            Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU -Name UseWuServer -Value $origAUVal -ErrorAction SilentlyContinue
        }
        if($origStatus -eq "Stopped")
        {
            Out-BoxstarterLog "Stopping win update service and setting its startup type to $origStartupType" -verbose
            Set-Service wuauserv -StartupType $origStartupType
            Remove-BoxstarterError { stop-service wuauserv -WarningAction SilentlyContinue }
        }
    }
}

function Download-Update($update) {
    $downloadSession = Start-TimedSection "Download of $($update.Title)"
    $updates = New-Object -com "Microsoft.Update.UpdateColl"
    $updates.Add($update) | Out-Null
    $Downloader.Updates = $updates

    $retry = $true
    [int]$retries = "10"
    [int]$currentRetry = "0"
    [int]$retrySeconds = 30

    do {
        try {
            $Downloader.Download() | Out-Null
            $retry = $false
        }
        catch {
            # Check for WU_E_SELFUPDATE_IN_PROGRESS
            if($_.Exception.HResult -eq -2145124325) {
                if ($currentRetry -gt $retries) {
                    # We can't wait forever...
                    Write-BoxstarterMessage "Windows Update Agent took too long to update itself."
                    throw
                }

                Write-BoxstarterMessage "Windows Update Agent is self-updating... Waiting."
                $global:error.RemoveAt(0)

                Start-Sleep -Seconds $retrySeconds
                $currentRetry = $currentRetry + 1
            }
            # Some other execption happened...
            else {
                throw
            }
        }
    } while ($retry -eq $true)

    Stop-TimedSection $downloadSession
}

function Install-Update($update, $currentCount, $totalUpdates) {
    $installSession=Start-TimedSection "Install $currentCount of $totalUpdates updates: $($update.Title)"
    $updates= New-Object -com "Microsoft.Update.UpdateColl"
    $updates.Add($update) | Out-Null
    $Installer.updates = $Updates
    try { $result = $Installer.Install() } catch {
        if(!($SuppressReboots) -and (Test-Path function:\Invoke-Reboot)){
            if(Test-PendingReboot){
                $global:error.RemoveAt(0)
                Invoke-Reboot
            }
        }
        # Check for WU_E_INSTALL_NOT_ALLOWED
        if($_.Exception.HResult -eq -2145124330) {
            Out-BoxstarterLog "There is either an update in progress or there is a pending reboot blocking the install."
            $global:error.RemoveAt(0)
        }
        else { throw }
    }
    Stop-TimedSection $installSession
    return $result
}
