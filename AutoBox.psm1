Import-Module $PSScriptRoot\Externals\PinnedApplications.psm1
import-module $PSScriptRoot\Externals\psake\psake.psm1
. $PSScriptRoot\Externals\VsixInstallFunctions.ps1

function Invoke-Autobox{
      param(
          [string]$bootstrapPackage="default",
          [switch]$justFinishedUpdates
      )
      try{Start-Transcript -path $env:temp\transcript.log -Append}catch{$autoboxIsNotTranscribing=$true}
      Stop-Service -Name wuauserv

      if($justFinishedUpdates -eq $false){
            $buildFile = "$PSScriptRoot\BuildPackages\$bootstrapPackage\default.ps1"
            invoke-psake $buildFile
      }

      if($global:RunUpdatesWhenDone -or $justFinishedUpdates){Force-Windows-Update $global:GetUpdatesFromMSWhenDone}
      Start-Service -Name wuauserv
      if(!$autoboxIsNotTranscribing){Stop-Transcript}
}
function Is64Bit {  [IntPtr]::Size -eq 8  }
function Download-File([string] $url, [string] $path) {
    Write-Host "Downloading $url to $path"
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $path) 
}
function Install-VS11-Beta {
    Install-ChocolateyPackage 'vs' 'exe' '/Passive /NoRestart /Full' 'http://go.microsoft.com/fwlink/?linkid=237587' 
}
function Disable-UAC {
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 0
}
function Add-ExplorerMenuItem([string]$name, [string]$label, [string]$command, [string]$type = "file"){
    if( -not (Test-Path -path HKCR:) ) {
        New-PSDrive -Name HKCR -PSProvider registry -Root Hkey_Classes_Root
    }
    if($type -eq "file") {$key = "*"} elseif($type -eq "directory") {$key="directory"} else{ return }
    if(!(test-path -LiteralPath "HKCR:\$key\shell\$name")) { new-item -Path "HKCR:\$key\shell\$name" }
    Set-ItemProperty -LiteralPath "HKCR:\$key\shell\$name" -Name "(Default)"  -Value "$label"
    if(!(test-path -LiteralPath "HKCR:\$key\shell\$name\command")) { new-item -Path "HKCR:\$key\shell\$name\command" }
    Set-ItemProperty -LiteralPath "HKCR:\$key\shell\$name\command" -Name "(Default)"  -Value "$command `"%1`""
}
function Choc([string] $package, [string]$source) {
    Check-Chocolatey
    $chocolatey="$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd"
    .$chocolatey install $package $source
}
function Enable-IIS-Win7 {
    .$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd install iis7 -source webpi
    DISM /Online /NoRestart /Enable-Feature /FeatureName:IIS-HttpCompressionDynamic 
    DISM /Online /NoRestart /Enable-Feature /FeatureName:IIS-ManagementScriptingTools 
    DISM /Online /NoRestart /Enable-Feature /FeatureName:IIS-WindowsAuthentication
}
function Enable-Telnet-Win7 {
    DISM /Online /NoRestart /Enable-Feature /FeatureName:TelnetClient 
}
function Enable-Net35 {
    $os = (Get-WmiObject -class Win32_OperatingSystem).Caption
    if($os.Contains('Server')){
        import-module servermanager
        Add-WindowsFeature "Net-Framework-Core"
    }
    elseif ($os.Contains('Windows 7')){DISM /Online /NoRestart /Enable-Feature /FeatureName:NetFx3}
}
function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319") -and -not $GetRepoOnly) {
        Import-Module $env:systemdrive\chocolatey\chocolateyinstall\helpers\chocolateyInstaller.psm1
        Install-ChocolateyZipPackage 'webcmd' 'http://www.iis.net/community/files/webpi/webpicmdline_anycpu.zip' $env:temp
        .$env:temp\WebpiCmdLine.exe /products: NetFramework4 /accepteula
    }
}
function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer -Force
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
function RunUpdatesWhenDone([switch]$getUpdatesFromMS)
{
    $global:RunUpdatesWhenDone = $true
    $global:GetUpdatesFromMSWhenDone = $getUpdatesFromMS
}
function Force-Windows-Update([switch]$getUpdatesFromMS) {
    if( Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat") {
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    }

    if($getUpdatesFromMS) {
        Remove-Item -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate -Force -Recurse -ErrorAction SilentlyContinue
        Stop-Service -Name wuauserv
        Start-Service -Name wuauserv
    }
    $updateSession =new-object -comobject "Microsoft.Update.Session"
    $updatesToDownload =new-Object -com "Microsoft.Update.UpdateColl"
    $updatesToInstall =new-object -com "Microsoft.Update.UpdateColl"
    $Downloader =$updateSession.CreateUpdateDownloader()
    $Installer =$updateSession.CreateUpdateInstaller()
    $Searcher =$updatesession.CreateUpdateSearcher()
    $Result = $Searcher.Search("IsInstalled=0 and Type='Software'")

    If ($Result.updates.count -ne 0)
    {
        write-host $Result.updates.count " Updates found"
        foreach($update in $result.updates) {
            if ($update.isDownloaded -ne "true") {
            	write-host " * Adding " $update.title " to list of updates to download"
                $updatesToDownload.add($update) | Out-Null
            }
			else {write-host " * " $update.title " already downloaded"}
        }

        If ($updatesToDownload.Count -gt 0) {
			Write-Host "Beginning to download " $updatesToDownload.Count " updates"
            $Downloader.Updates = $updatesToDownload
            $Downloader.Download()
        }
		
        write-host "Downloading complete"
        foreach($update in $result.updates) {
            $updatesToinstall.add($update) | Out-Null
        }

		Write-Host "Beginning to install"
        $Installer.updates = $UpdatesToInstall
        $result = $Installer.Install()

        if($result.rebootRequired) {
            $myLocation = (Split-Path -parent $MyInvocation.MyCommand.path)
            New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "powershell -NonInteractive -NoProfile -ExecutionPolicy bypass -Command `"& '%~dp0bootstrap.ps1' -JustFinishedUpdates`""
			Write-Host "Restart Required. Restarting now..."
            Restart-Computer -force
        }
		Write-Host "All updates installed"
    }
    else{write-host "There is no update applicable to this machine"}    
}
function Set-FileAssociation([string]$extOrType, [string]$command) {
    if(-not($extOrType.StartsWith("."))) {$fileType=$extOrType}
    if($fileType -eq $null) {
        $testType = (cmd /c assoc $extOrType)
        if($testType -ne $null) {$fileType=$testType.Split("=")[1]}
    }
    if($fileType -eq $null) {
        write-host "Unable to Find File Type for $extOrType"
    }
    else {
        write-host "Associating $fileType with $command"
        $assocCmd = "ftype $fileType=`"$command`" %1"
        cmd /c $assocCmd
    }
}
function Configure-ExplorerOptions([switch]$showHidenFilesFoldersDrives, [switch]$showProtectedOSFiles, [switch]$showFileExtensions) {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if($showHidenFilesFoldersDrives) {Set-ItemProperty $key Hidden 1}
    if($showFileExtensions) {Set-ItemProperty $key HideFileExt 0}
    if($showProtectedOSFiles) {Set-ItemProperty $key ShowSuperHidden 1}
    Stop-Process -processname explorer -Force
}
function Check-Chocolatey{
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        New-Item $env:systemdrive\chocolatey -Force -type directory
        iex ((new-object net.webclient).DownloadString('http://bit.ly/psChocInstall'))
        Import-Module $env:systemdrive\chocolatey\chocolateyinstall\helpers\chocolateyInstaller.psm1
    }
}

Export-ModuleMember Invoke-Autobox
