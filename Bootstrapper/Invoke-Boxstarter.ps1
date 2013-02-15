$Boxstarter = @{Log="$env:temp\boxstarter.log";RebootOk=$false;SuppressLogging=$false;IsRebooting=$false}

function Invoke-BoxStarter{
<#
.SYNOPSIS
Invokes the Boxstarter bootstrapper

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

 .PARAMETER BootstrapPackage
 The package to be installed.
 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

.Parameter Password
This password will be used to automatically log the user in if a 
reboot is required and reboots are eabled.

.Parameter RebootOk
If set, a reboot will be performed if boxstarter determines that a 
reboot is pending. Boxstarter will prompt the user to enter a 
password which will be used for automatic logins in the event a 
restart is required.

.Parameter ReEnableUAC
This parameter is intended to be set by Boxstarter If boxstarter 
needs to disable UAC in order to suppress the security prompt 
after reboot when relaunching boxstarter as admin, it will set 
this switch which will cause boxstarter to turn UAC back on aftr 
the reboot completes.

.Parameter Localrepo
This is the path to the local boxstarter repository where boxstarter 
should look for .nupkg files to install. By default this is located 
in the BuildPackages directory just under the root Boxstarter 
directory.

.EXAMPLE
Invoke-Boxstarter example -RebootOk

This invokes boxstarter an installs the example .nupkg. In pending 
reboots are detected, boxstarter will restart the machine. Boxstarter
will prompt the user to enter a password which will be used for 
automatic logins in the event a restart is required.

.EXAMPLE
Invoke-Boxstarter win8Install -rebootOk -LocalRepo \\server\share\boxstarter

This installs the Win8Install .nupkg and specifies that it is ok to 
reboot the macine if a pending reboot is needed. Boxstarter will look 
for the Win8Install .nupkg file in the \\serer\share\boxstarter 
directory.

.LINK
http://boxstarter.codeplex.com
About_Boxstarter_Variable
#>    
    [CmdletBinding()]
    param(
      [ScriptBlock]$ScriptToCall
      [System.Security.SecureString]$password,
      [switch]$RebootOk,
      [switch]$ReEnableUAC
    )
    $boxMod=Get-Module Boxstarter
    write-BoxstarterMessage "Boxstarter Version $($boxMod.Version)" -nologo
    write-BoxstarterMessage "$($boxMod.Copyright)" -nologo
    $session=Start-TimedSection "Installation session of package $bootstrapPackage"
    try{
        if($ReEnableUAC) {Enable-UAC}
        $script:BoxstarterPassword=InitAutologon -RebootOk:$RebootOk $password
        $script:BoxstarterUser=$env:username
        $Boxstarter.RebootOk=$RebootOk
        $Boxstarter.ScriptToCall = $ScriptToCall
        Stop-UpdateServices
        &($ScriptToCall)
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
        write-BoxstarterMessage "Succesfully authenticated password."
    }
    if($val){return $password} else {
        write-BoxstarterMessage "Unable to authenticate password. Proceeding with autologon disabled"
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