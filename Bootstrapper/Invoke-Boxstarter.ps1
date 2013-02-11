if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
$Boxstarter = @{ProgramFiles86="$programFiles86";ChocolateyBin="$env:systemdrive\chocolatey\bin";Log="$env:temp\boxstarter.log";RebootOk=$false;SuppressLogging=$false}

function Invoke-BoxStarter{
<#
.SYNOPSIS
Invokes the installation of a Boxstarter package

.DESCRIPTION
This essentially wraps Chocolatey Install and provides these additional features
 - Installs chocolatey if it is not already installed
 - Installs the .net 4.0 framework if it is not installed which is a chocolatey requirement
 - Turns off the windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.Helpers module that provides functions for customizing windows
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under admin

 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

 .PARAMETER bootstrapPackage
 The package to be installed.
 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

#>    
    [CmdletBinding()]
    param(
      [string]$bootstrapPackage="default",
      [System.Security.SecureString]$password,
      [switch]$RebootOk,
      [switch]$ReEnableUAC,
      [string]$localRepo="$baseDir\BuildPackages"
    )
    $session=Start-TimedSection "Installation session of package $bootstrapPackage"
    try{
        if($ReEnableUAC) {Enable-UAC}
        $script:BoxstarterPassword=InitAutologon -RebootOk:$RebootOk $password
        $script:BoxstarterUser=$env:username
        $Boxstarter.RebootOk=$RebootOk
        $Boxstarter.Package=$bootstrapPackage
        $Boxstarter.LocalRepo=Resolve-LocalRepo $localRepo
        Check-Chocolatey
        del "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -ErrorAction SilentlyContinue
        del "$env:systemdrive\chocolatey\lib\$bootstrapPackage.*" -recurse -force -ErrorAction SilentlyContinue
        Stop-UpdateServices
        Get-HelperModule
        Download-Package $bootstrapPackage
    }
    finally{
        Cleanup-Boxstarter
        Stop-TimedSection $session
    }
}

function Read-AuthenticatedPassword {
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    if($env:computername -eq $env:UserDomain) {
        $pctx = [System.DirectoryServices.AccountManagement.ContextType]::Machine
    } else {
        $pctx = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    }
    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $pctx,$env:UserDomain
    $attemptsLeft=3
    while(--$attemptsLeft -ge 0 -and !$val) {
        $Password=Read-Host -AsSecureString "Autologon Password"
        $BSTR = [System.Runtime.InteropServices.marshal]::SecureStringToBSTR( $password);
        $plainpassword = [System.Runtime.InteropServices.marshal]::PtrToStringAuto($BSTR);
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR);
        $val = $pc.ValidateCredentials($env:username, $plainpassword, [System.DirectoryServices.AccountManagement.ContextOptions]::Negotiate)    
    }
    if($val){return $password} else {
        write-host "Unable to authenticate your password. Proceeding with autologon disabled"
        return $null
    }
}

function InitAutologon([switch]$RebootOk, [System.Security.SecureString]$password){
    $autologonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $autoLogon=Get-ItemProperty -Path $autologonKey -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    if($autoLogon) {
        $autoLogon = $autoLogon.AutoAdminLogon
        if($autoLogon -gt 0) {
            $autoLogonCount=Get-ItemProperty -Path $autologonKey -Name "AutoLogonCount" -ErrorAction SilentlyContinue
            if($autoLogonCount) {$autoLogon=$autoLogonCount.autoLogonCount}
        }
    } else {$autoLogon=0}
    $Boxstarter.AutologedOn = ($autoLogon -gt 0)
    if($RebootOk -and !$Password -and !$Boxstarter.AutologedOn) {
        write-host "Boxstarter may need to reboot your system. Please provide your password so that Boxstarter may automatically log you on. Your password will be securely stored and encrypted."
        $Password=Read-AuthenticatedPassword
    }
    return $password
}

function Resolve-LocalRepo([string]$localRepo) {
    write-host "entering localRepo resolution"
    if($localRepo){
        $localRepo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($localRepo)
    }
    write-host "LocalRepo is at $localRepo"
    return $localRepo
}

function Get-HelperModule {
    if(Test-Path (Join-Path $Boxstarter.LocalRepo "boxstarter.Helpers.*.nupkg")) { 
        $helperSrc = $Boxstarter.LocalRepo
    }
    write-output "Checking for latest helper $(if($helperSrc){'locally'})"
    Try-LoadHelpers #Get old version if necessary to examine UAC
    Chocolatey update boxstarter.helpers $helperSrc
    Try-LoadHelpers #Get the update if there is one
}

function Try-LoadHelpers {
    $helperDir = (Get-ChildItem $env:ChocolateyInstall\lib\boxstarter.helpers*)
    if($helperDir.Count -gt 1){$helperDir = $helperDir[-1]}
    if($helperDir) { 
        if(Get-Module boxstarter.helpers){Remove-Module boxstarter.helpers}
        import-module $helperDir\boxstarter.helpers.psm1 
    }
}

function Download-Package([string]$bootstrapPackage) {
    if(test-path (Join-Path $Boxstarter.LocalRepo "$bootstrapPackage.*.nupkg")){
        $source = $Boxstarter.LocalRepo
    } else {
        $source = "http://chocolatey.org/api/v2;http://www.myget.org/F/boxstarter/api/v2"
    }
    write-output "Installing Boxstarter package from $source"
    Chocolatey install $bootstrapPackage -source $source -force
}