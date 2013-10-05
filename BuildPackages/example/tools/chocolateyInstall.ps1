try {
    Update-ExecutionPolicy Unrestricted
    Move-LibraryDirectory "Personal" "$env:UserProfile\skydrive\documents"
    Set-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
    Set-TaskbarSmall
    Enable-RemoteDesktop

    cinstm VisualStudio2012Ultimate
    if((Get-Item "$($Boxstarter.programFiles86)\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe").VersionInfo.ProductVersion -lt "11.0.60115.1") {
        if(Test-PendingReboot){Invoke-Reboot}
        Install-ChocolateyPackage 'vs update 2 ctp2' 'exe' '/passive /norestart' 'http://download.microsoft.com/download/8/9/3/89372D24-6707-4587-A7F0-10A29EECA317/vsupdate_KB2707250.exe'
    }
    cinstm fiddler
    cinstm mssqlserver2012express
    cinstm git-credential-winstore
    cinstm console-devel
    cinstm sublimetext2
    cinstm skydrive
    cinstm poshgit
    cinstm dotpeek
    cinstm googlechrome
    cinstm Paint.net
    cinstm windirstat
    cinstm sysinternals
    cinstm NugetPackageExplorer
    cinstm resharper
    cinstm winrar
    cinstm windbg

    cinst Microsoft-Hyper-V-All -source windowsFeatures
    cinst IIS-WebServerRole -source windowsfeatures
    cinst IIS-HttpCompressionDynamic -source windowsfeatures
    cinst IIS-ManagementScriptingTools -source windowsfeatures
    cinst IIS-WindowsAuthentication -source windowsfeatures
    cinst TelnetClient -source windowsFeatures

    $sublimeDir = "$env:programfiles\Sublime Text 2"
    Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\mstsc.exe"
    Install-ChocolateyPinnedTaskBarItem "$env:programfiles\console\console.exe"
    Install-ChocolateyPinnedTaskBarItem "$sublimeDir\sublime_text.exe"
    Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Google\Chrome\Application\chrome.exe"
    Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"

    Install-ChocolateyFileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
    Install-ChocolateyFileAssociation ".dll" "$($Boxstarter.programFiles86)\jetbrains\dotpeek\v1.1\Bin\dotpeek32.exe"

    if(!(Test-Path "$sublimeDir\data")){mkdir "$sublimeDir\data"}
    copy-item (Join-Path (Get-PackageRoot($MyInvocation)) 'sublime\*') -Force -Recurse "$sublimeDir\data"
    move-item "$sublimeDir\data\Pristine Packages\*" -Force "$sublimeDir\Pristine Packages"
    copy-item (Join-Path (Get-PackageRoot($MyInvocation)) 'console.xml') -Force $env:appdata\console\console.xml

    Install-ChocolateyVsixPackage xunit http://visualstudiogallery.msdn.microsoft.com/463c5987-f82b-46c8-a97e-b1cde42b9099/file/66837/1/xunit.runner.visualstudio.vsix
    Install-ChocolateyVsixPackage autowrocktestable http://visualstudiogallery.msdn.microsoft.com/ea3a37c9-1c76-4628-803e-b10a109e7943/file/73131/1/AutoWrockTestable.vsix
    Install-ChocolateyVsixPackage vscommands http://visualstudiogallery.msdn.microsoft.com/a83505c6-77b3-44a6-b53b-73d77cba84c8/file/74740/18/SquaredInfinity.VSCommands.VS11.vsix
    Install-WindowsUpdate -AcceptEula
    Write-ChocolateySuccess 'example'
} catch {
  Write-ChocolateyFailure 'example' $($_.Exception.Message)
  throw
}