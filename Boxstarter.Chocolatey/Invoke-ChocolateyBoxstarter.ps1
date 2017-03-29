function Invoke-ChocolateyBoxstarter{
<#
.SYNOPSIS
Invokes the installation of a Boxstarter package

.DESCRIPTION
This essentially wraps Chocolatey Install and provides these additional features
 - Installs chocolatey if it is not already installed
 - Installs the .net 4.5 framework if it is not installed which is a chocolatey requirement
 - Disables windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.WinConfig module that provides functions for customizing windows
 - Detects pending reboots and restarts the machine when necessary to avoid installation failures
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under administrator permissions

 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The Chocolatey feed
 - The Boxstarter feed on MyGet
 This can be configured by editing $($Boxstarter.BaseDir)\Boxstarter.Config

 If the package name provided is a URL or resolves to a file. Then 
 it is assumed that this contains the chocolatey install script and
 a .nupkg file will be created using the script.
 
 .PARAMETER BootstrapPackage
 The names of one or more Nuget Packages to be installed or URIs or 
 file paths pointing to a chocolatey script. If using package names,
 the .nupkg file for the provided package names are searched in the 
 following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The Chocolatey feed
 - The Boxstarter feed on MyGet

.Parameter LocalRepo
This is the path to the local boxstarter repository where boxstarter 
should look for .nupkg files to install. By default this is located 
in the BuildPackages directory just under the root Boxstarter 
directory but can be changed with Set-BoxstarterConfig.

.PARAMETER DisableReboots
If set, reboots are suppressed.

.PARAMETER Password
User's password as a Secure string to be used for reboot autologon's.
This will suppress the password prompt at the beginning of the 
Boxstarter installer.

.PARAMETER KeepWindowOpen
Enabling this switch will prevent the command window from closing and 
prompt the user to pres the Enter key before the window closes. This 
is ideal when not invoking boxstarter from a console.

.PARAMETER NoPassword
When set, Boxstarter will never prompt for logon. Use this if using
an account without password validation.

.NOTES
If specifying only one package, Boxstarter calls chocolatey with the 
-force argument and deletes the previously installed package directory. 
This means that regardless of whether or not the package had been 
installed previously, Boxstarter will attempt to download and reinstall it.
This only holds true for the outer package. If the package contains calls 
to CINST for additional packages, those installs will not reinstall if 
previously installed.

If an array of package names are passed to Invoke-ChocolateyBoxstarter, 
Boxstarter will NOT apply the above reinstall logic and will skip the 
install for any package that had been previously installed.

.EXAMPLE
Invoke-ChocolateyBoxstarter "example1","example2"

This invokes boxstarter and installs the example1 and example2 .nupkg 
files. If pending reboots are detected, boxstarter will restart the 
machine. Boxstarter will prompt the user to enter a password which will 
be used for automatic logins in the event a restart is required.

.EXAMPLE
Invoke-ChocolateyBoxstarter https://gist.github.com/mwrock/6771863/raw/b579aa269c791a53ee1481ad01711b60090db1e2/gistfile1.txt

This invokes boxstarter and installs the script uploaded to the github gist.

.EXAMPLE
Invoke-ChocolateyBoxstarter script.ps1

This invokes boxstarter and installs the script located at script.ps1 
in the command line's current directory.

.EXAMPLE
Invoke-ChocolateyBoxstarter \\server\share\script.ps1

This invokes boxstarter and installs the script located at the 
specified share.

.EXAMPLE
Invoke-ChocolateyBoxstarter win8Install -LocalRepo \\server\share\boxstarter

This installs the Win8Install .nupkg and specifies that it is OK to 
reboot the machine if a pending reboot is needed. Boxstarter will look 
for the Win8Install .nupkg file in the \\serer\share\boxstarter 
directory.

.EXAMPLE
Invoke-ChocolateyBoxstarter example -Password (ConvertTo-SecureString "mypassword" -AsPlainText -Force)

This installs the example package and uses "mypassword" for any reboot 
autologon's. The user is now not prompted for a password.

.LINK
http://boxstarter.org
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
Set-BoxstarterConfig
#>    
    [CmdletBinding()]
    param(
      [string[]]$BootstrapPackage=$null,
      [string]$LocalRepo,
      [switch]$DisableReboots,
      [System.Security.SecureString]$Password,
      [switch]$KeepWindowOpen,
      [switch]$NoPassword,
      [switch]$DisableRestart
    )
    try{
        if($DisableReboots){
            Write-BoxstarterMessage "Disabling reboots" -Verbose
            $Boxstarter.RebootOk=$false
        }
        if($Boxstarter.ScriptToCall -eq $null){
            if($bootstrapPackage -ne $null -and $bootstrapPackage.length -gt 0){
                write-BoxstarterMessage "Installing package $($bootstrapPackage -join ', ')" -Color Cyan
            }
            else{
                write-BoxstarterMessage "Installing Chocolatey" -Color Cyan
            }
            $scriptArgs=@{}
            if($bootstrapPackage){$scriptArgs.bootstrapPackage=$bootstrapPackage}
            if($LocalRepo){$scriptArgs.Localrepo=$localRepo}
            if($DisableReboots){$scriptArgs.DisableReboots = $DisableReboots}
            $script=@"
Import-Module (Join-Path "$($Boxstarter.baseDir)" BoxStarter.Chocolatey\Boxstarter.Chocolatey.psd1) -global -DisableNameChecking;
Invoke-ChocolateyBoxstarter $(if($bootstrapPackage){"-bootstrapPackage '$($bootstrapPackage -join ''',''')'"}) $(if($LocalRepo){"-LocalRepo $localRepo"})  $(if($DisableReboots){"-DisableReboots"})
"@
            Invoke-Boxstarter ([ScriptBlock]::Create($script)) -RebootOk:$Boxstarter.RebootOk -password $password -KeepWindowOpen:$KeepWindowOpen -NoPassword:$NoPassword -DisableRestart:$DisableRestart
            return
        }
        if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
        $Boxstarter.ProgramFiles86="$programFiles86"
        $Boxstarter.LocalRepo=Resolve-LocalRepo $localRepo
        if($bootstrapPackage -ne $null){
            Download-Package $bootstrapPackage
        }
    }
    finally {
        $Boxstarter.ScriptToCall = $null
    }
}

function Resolve-LocalRepo([string]$localRepo) {
    if($localRepo){
        $localRepo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($localRepo)
    } else {$Localrepo = $Boxstarter.Localrepo}
    write-BoxstarterMessage "LocalRepo is at $localRepo" -Verbose
    return $localRepo
}

function Download-Package([string[]]$bootstrapPackage) {
    $BootstrapPackage = $BootstrapPackage | % {
        if($_ -like "*://*" -or (Test-Path $_ -PathType Leaf)){
            New-PackageFromScript -Source $_ -PackageName $( split-path -leaf ([System.IO.Path]::GetTempFileName()))
        }
        else {
            $_
        }
    }
    $Boxstarter.Package=$bootstrapPackage
    $force=$false
    if($bootstrapPackage.Count -eq 1){
        Write-BoxstarterMessage "Deleting previous $bootstrapPackage package" -Verbose
        $chocoRoot = $env:ChocolateyInstall
        if($chocoRoot -eq $null) {
            $chocoRoot = "$env:programdata\chocolatey"
        }
        if(Test-Path "$chocoRoot\lib"){
            @(
                "$chocoRoot\lib\$bootstrapPackage.*",
                "$chocoRoot\lib\$bootstrapPackage"
            ) | % {
                if(Test-Path $_){
                    del $_ -recurse -force -ErrorAction SilentlyContinue
                    Write-BoxstarterMessage "Deleted $_" -verbose
                }
            }
        }
        $force=$true
    }
    $source = "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"
    write-BoxstarterMessage "Installing $($bootstrapPackage.Count) packages from $source" -Verbose
    Chocolatey install $bootstrapPackage -source $source -force:$force -execution-timeout 86400
}