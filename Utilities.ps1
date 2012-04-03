function Download-File([string] $url, [string] $path) {
    Write-Host "Downloading $url to $path"
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $path) 
}

function Install-VS11-Beta {
    Download-File http://go.microsoft.com/fwlink/?linkid=237587 vs.exe
    vs /Passive /NoRestart /Full
}
function Disable-UAC {
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 0
}
function Enable-IIS-Win7 {
    DISM /Online /Enable-Feature /FeatureName:IIS-WebServerRole 
    DISM /Online /Enable-Feature /FeatureName:IIS-WebServer 
    DISM /Online /Enable-Feature /FeatureName:IIS-CommonHttpFeatures 
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpErrors 
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpRedirect 
    DISM /Online /Enable-Feature /FeatureName:IIS-ApplicationDevelopment 
    DISM /Online /Enable-Feature /FeatureName:IIS-Security 
    DISM /Online /Enable-Feature /FeatureName:IIS-RequestFiltering 
    DISM /Online /Enable-Feature /FeatureName:IIS-NetFxExtensibility 
    DISM /Online /Enable-Feature /FeatureName:IIS-HealthAndDiagnostics 
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpLogging 
    DISM /Online /Enable-Feature /FeatureName:IIS-LoggingLibraries 
    DISM /Online /Enable-Feature /FeatureName:IIS-RequestMonitor 
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpTracing 
    DISM /Online /Enable-Feature /FeatureName:IIS-Performance 
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpCompressionDynamic 
    DISM /Online /Enable-Feature /FeatureName:IIS-WebServerManagementTools
    DISM /Online /Enable-Feature /FeatureName:IIS-ManagementScriptingTools 
    DISM /Online /Enable-Feature /FeatureName:WAS-WindowsActivationService 
    DISM /Online /Enable-Feature /FeatureName:WAS-ProcessModel 
    DISM /Online /Enable-Feature /FeatureName:WAS-ConfigurationAPI
    DISM /Online /Enable-Feature /FeatureName:WAS-ProcessModel  
    DISM /Online /Enable-Feature /FeatureName:WAS-NetFxEnvironment  
    DISM /Online /Enable-Feature /FeatureName:IIS-ISAPIExtensions  
    DISM /Online /Enable-Feature /FeatureName:IIS-ISAPIFilter 
    DISM /Online /Enable-Feature /FeatureName:IIS-StaticContent 
    DISM /Online /Enable-Feature /FeatureName:IIS-DefaultDocument 
    DISM /Online /Enable-Feature /FeatureName:IIS-DirectoryBrowsing 
    DISM /Online /Enable-Feature /FeatureName:IIS-ASPNET 
    DISM /Online /Enable-Feature /FeatureName:IIS-CustomLogging 
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpCompressionStatic 
    DISM /Online /Enable-Feature /FeatureName:IIS-ManagementConsole 
    DISM /Online /Enable-Feature /FeatureName:IIS-WMICompatibility 
    DISM /Online /Enable-Feature /FeatureName:IIS-WindowsAuthentication
}
function Enable-Telnet-Win7 {
    DISM /Online /Enable-Feature /FeatureName:TelnetClient 
}
function Force-Windows-Update {
    remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    $updateSession =new-object -comobject "Microsoft.Update.Session"
    $updatesToDownload =new-Object -com "Microsoft.Update.UpdateColl"
    $updatesToInstall =new-object -com "Microsoft.Update.UpdateColl"
    $Downloader =$updateSession.CreateUpdateDownloader()
    $Installer =$updateSession.CreateUpdateInstaller()
    $Searcher =$updatesession.CreateUpdateSearcher()
    $Result = $Searcher.Search("IsInstalled=0 and Type='Software'")

    If ($Result.updates.count -ne 0)
    {
        foreach($update in $result.updates) {
            write-host "Downloading Update:" $update.title
            if ($update.isDownloaded -ne "true") {
                $updatesToDownload.add($update)
            }
        }

        If ($updatesToDownload.Count -gt 0) {
            $Downloader.Updates =$updatesToDownload
            $Downloader.Download()
        }

        foreach($update in $result.updates) {
            write-host "Installing Updates:" $update.title
            $updatesToinstall.add($update)
        }

        $Installer.updates =$UpdatesToInstall
        $result = $Installer.Install()

        if($result.rebootRequired) {
            $myLocation = (Split-Path -parent $MyInvocation.MyCommand.path)
            New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "powershell -NonInteractive -NoProfile -ExecutionPolicy bypass -Command `"& '%~dp0bootstrap.ps1' -JustFinishedUpdates`""
            Restart-Computer -force
        }
    }
    else{write-host "There is no update applicable to this machine"}    
}