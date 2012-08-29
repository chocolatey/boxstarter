. $PSScriptRoot\Externals\PinnedApplications.ps1
. $PSScriptRoot\Externals\VsixInstallFunctions.ps1

function Invoke-BoxStarter{
    param(
      [string]$bootstrapPackage="default"
    )
    try{
        try{Start-Transcript -path $env:temp\boxstrter.log -Append}catch{$BoxStarterIsNotTranscribing=$true}
        Stop-Service -Name wuauserv

        $localRepo = "$PSScriptRoot\BuildPackages"
        New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "$PSScriptRoot\BoxStarter.bat $bootstrapPackage"
        if( Test-Path "$localRepo\$bootstrapPackage.*.nupkg") {
            cinst $bootstrapPackage -source $localRepo -force
        }
        else {
            cinst all -source http://www.myget.org/F/$bootstrapPackage/ -force
        }

        if($global:InstallWindowsUpdateWhenDone){Install-WindowsUpdate $global:GetUpdatesFromMSWhenDone}
        Start-Service -Name wuauserv
        if(!$BoxStarterIsNotTranscribing){Stop-Transcript}
    }
    finally{
        if( Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat") {
            remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
        }
    }
}

function Is64Bit {  [IntPtr]::Size -eq 8  }
function Download-File([string] $url, [string] $path) {
    Write-Output "Downloading $url to $path"
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $path) 
}
function Disable-UAC {
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 0
}
function Add-ExplorerMenuItem([string]$menuKey, [string]$menuLabel, [string]$command, [ValidateSet('file','directory')][string]$type = "file"){
    if( -not (Test-Path -path HKCR:) ) {
        New-PSDrive -Name HKCR -PSProvider registry -Root Hkey_Classes_Root
    }
    if($type -eq "file") {$key = "*"} elseif($type -eq "directory") {$key="directory"} else{ return }
    if(!(test-path -LiteralPath "HKCR:\$key\shell\$menuKey")) { new-item -Path "HKCR:\$key\shell\$menuKey" }
    Set-ItemProperty -LiteralPath "HKCR:\$key\shell\$menuKey" -Name "(Default)"  -Value "$menuLabel"
    if(!(test-path -LiteralPath "HKCR:\$key\shell\$menuKey\command")) { new-item -Path "HKCR:\$key\shell\$menuKey\command" }
    Set-ItemProperty -LiteralPath "HKCR:\$key\shell\$menuKey\command" -Name "(Default)"  -Value "$command `"%1`""
}
function cinst {
    Check-Chocolatey
    $chocolatey="$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd"
    .$chocolatey install $args
}
function Install-FromChocolatey {
    Check-Chocolatey
    $chocolatey="$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd"
    .$chocolatey installmissing $args
}
function Move-LibraryDirectory ([string]$libraryName, [string]$newPath) {
    #why name the key downloads when you can name it {374DE290-123F-4565-9164-39C4925E467B}? duh.
    if($libraryName.ToLower() -eq "downloads") {$libraryName="{374DE290-123F-4565-9164-39C4925E467B}"}
    $shells = (Get-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders')
    if(-not $shells.Property.Contains($libraryName)) {
        throw "$libraryName is not a valid Library"
    }
    $oldPath =  (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -name "$libraryName")."$libraryName"
    if(-not (test-path "$newPath")){
        New-Item $newPath -type directory
    }
    if((resolve-path $oldPath).Path -eq (resolve-path $newPath).Path) {return}
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' $libraryName $newPath
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' $libraryName $newPath
    Stop-Process -processname explorer -Force
    Move-Item -Force $oldPath/* $newPath
}
function Enable-HyperV {
    DISM /Online /NoRestart /Enable-Feature /FeatureName:Microsoft-Hyper-V
    DISM /Online /NoRestart /Enable-Feature /all /FeatureName:Microsoft-Hyper-V-Management-Clients
}
function Enable-IIS {
    .$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd install iis7 -source webpi
    DISM /Online /NoRestart /Enable-Feature /FeatureName:IIS-HttpCompressionDynamic 
    DISM /Online /NoRestart /Enable-Feature /FeatureName:IIS-ManagementScriptingTools 
    DISM /Online /NoRestart /Enable-Feature /FeatureName:IIS-WindowsAuthentication
}
function Enable-Telnet {
    DISM /Online /NoRestart /Enable-Feature /FeatureName:TelnetClient 
}
function Enable-Net35 {
    DISM /Online /NoRestart /Enable-Feature /FeatureName:NetFx3
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
    Write-Output "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
function Install-WindowsUpdateWhenDone([switch]$getUpdatesFromMS)
{
    $global:InstallWindowsUpdateWhenDone = $true
    $global:GetUpdatesFromMSWhenDone = $getUpdatesFromMS
}
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
function Set-FileAssociation([string]$extOrType, [string]$command) {
    if(-not($extOrType.StartsWith("."))) {$fileType=$extOrType}
    if($fileType -eq $null) {
        $testType = (cmd /c assoc $extOrType)
        if($testType -ne $null) {$fileType=$testType.Split("=")[1]}
    }
    if($fileType -eq $null) {
        Write-Output "Unable to Find File Type for $extOrType"
    }
    else {
        Write-Output "Associating $fileType with $command"
        $assocCmd = "ftype $fileType=`"$command`" %1"
        cmd /c $assocCmd
    }
}
function Set-ExplorerOptions([switch]$showHidenFilesFoldersDrives, [switch]$showProtectedOSFiles, [switch]$showFileExtensions) {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if($showHidenFilesFoldersDrives) {Set-ItemProperty $key Hidden 1}
    if($showFileExtensions) {Set-ItemProperty $key HideFileExt 0}
    if($showProtectedOSFiles) {Set-ItemProperty $key ShowSuperHidden 1}
    Stop-Process -processname explorer -Force
}
function Set-TaskbarSmall {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty $key TaskbarSmallIcons 1
    Stop-Process -processname explorer -Force
}
function Check-Chocolatey{
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
        New-Item $env:ChocolateyInstall -Force -type directory
        iex ((new-object net.webclient).DownloadString('http://bit.ly/psChocInstall'))
        Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
    }
}
function Add-PersistentEnvVar ($name, $value) {
    [Environment]::SetEnvironmentVariable($name,$value, 'Machine')
    Set-content "env:\$name" $value
}
function Enable-RemoteDesktop {
    (Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices).SetAllowTsConnections(1)
    netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
}
Export-ModuleMember Invoke-BoxStarter, Set-PinnedApplication, Enable-Telnet, Add-ExplorerMenuItem, Set-FileAssociation, Install-FromChocolatey, Disable-UAC, Enable-IIS, Enable-Net35, Enable-Net40, Disable-InternetExplorerESC, Install-WindowsUpdateWhenDone, Set-ExplorerOptions, Set-TaskbarSmall, Install-WindowsUpdate, Install-VsixSilently,Add-PersistentEnvVar, Move-LibraryDirectory, Enable-HyperV, Enable-RemoteDesktop