function Install-WindowsUpdate([switch]$getUpdatesFromMS) {
    if($getUpdatesFromMS) {
        Remove-Item -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate -Force -Recurse -ErrorAction SilentlyContinue
        Stop-Service -Name wuauserv
        Start-Service -Name wuauserv
    }
    Write-Output "Checking for updates..."
    $updateSession =new-object -comobject "Microsoft.Update.Session"
    $updatesToDownload =new-Object -com "Microsoft.Update.UpdateColl"
    $updatesToInstall =new-object -com "Microsoft.Update.UpdateColl"
    $Downloader =$updateSession.CreateUpdateDownloader()
    $Installer =$updateSession.CreateUpdateInstaller()
    $Searcher =$updatesession.CreateUpdateSearcher()
    $Result = $Searcher.Search("IsInstalled=0 and Type='Software'")

    If ($Result.updates.count -ne 0)
    {
        Write-Output $Result.updates.count " Updates found"
        foreach($update in $result.updates) {
            if ($update.isDownloaded -ne "true") {
                Write-Output " * Adding " $update.title " to list of updates to download"
                $updatesToDownload.add($update) | Out-Null
            }
            else {Write-Output " * " $update.title " already downloaded"}
        }

        If ($updatesToDownload.Count -gt 0) {
            Write-Output "Beginning to download " $updatesToDownload.Count " updates"
            $Downloader.Updates = $updatesToDownload
            $Downloader.Download()
        }
        
        Write-Output "Downloading complete"
        foreach($update in $result.updates) {
            $updatesToinstall.add($update) | Out-Null
        }

        Write-Output "Beginning to install"
        $Installer.updates = $UpdatesToInstall
        $result = $Installer.Install()

        if($result.rebootRequired) {
            if($global:InstallWindowsUpdateWhenDone) {
                New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "powershell -NonInteractive -NoProfile -ExecutionPolicy bypass -Command `"Import-Module '$PSScriptRoot\BoxStarter.psm1';Install-WindowsUpdate`""
            }
            Write-Output "Restart Required. Restarting now..."
            Restart-Computer -force
        }
        Write-Output "All updates installed"
    }
    else{Write-Output "There is no update applicable to this machine"}    
}
