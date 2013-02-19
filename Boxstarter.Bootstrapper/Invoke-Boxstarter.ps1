if(!$Boxstarter) {$Boxstarter = @{}}
$Boxstarter.Log="$env:temp\boxstarter.log"
$Boxstarter.RebootOk=$false
$Boxstarter.SuppressLogging=$false
$Boxstarter.IsRebooting=$false

function Invoke-BoxStarter{
<#
.SYNOPSIS
Invokes the Boxstarter bootstrapper

.DESCRIPTION
This wraps any powershell script block and executes it in an environment tailored for uninterrupted installations
 - Turns off the windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.WinConfig module that provides functions for customizing windows
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under admin

.Parameter ScriptToCall
The script that boxstarter wraps. After Boxstarter Shuts down 
the update services and ensures that the console is running as 
admin, it invokes this script. The script may call Invoke-Reboot 
at any time and Boxstarter will ensure that the machine is 
rebooted, loged in and the script is rerun.

.Parameter Password
This password will be used to automatically log the user in if a 
reboot is required and reboots are eabled.

.Parameter RebootOk
If set, a reboot will be performed if boxstarter determines that a 
reboot is pending. Boxstarter will prompt the user to enter a 
password which will be used for automatic logins in the event a 
restart is required.

.EXAMPLE
Invoke-Boxstarter {Import-Modler myinstaller;Invoke-MyInstall} -RebootOk

This invokes boxstarter and iinvokes MyInstall. If pending 
reboots are detected, boxstarter will restart the machine. Boxstarter
will prompt the user to enter a password which will be used for 
automatic logins in the event a restart is required.

.LINK
http://boxstarter.codeplex.com
About_Boxstarter_Variable
#>    
    [CmdletBinding()]
    param(
      [ScriptBlock]$ScriptToCall,
      [System.Security.SecureString]$password,
      [switch]$RebootOk
    )
    $scriptFile = "$env:temp\boxstarter.script"
    if(!(Test-Admin)) {
        New-Item $scriptFile -type file -value $ScriptToCall.ToString() -force | out-null
        Write-BoxstarterMessage "User is not running with administrative rights. Attempting to elevate."
        $command = "-ExecutionPolicy bypass -noexit -command Import-Module `"$($Boxstarter.Basedir)\Boxstarter.Bootstrapper\BoxStarter.Bootstrapper.psd1`";Invoke-BoxStarter $(if($RebootOk){'-RebootOk'})"
        Start-Process powershell -verb runas -argumentlist $command
        return
    }
    $boxMod=Get-Module Boxstarter
    write-BoxstarterMessage "Boxstarter Version $($boxMod.Version)" -nologo
    write-BoxstarterMessage "$($boxMod.Copyright)" -nologo
    $session=Start-TimedSection "Installation session of package $bootstrapPackage"
    try{
        if(Test-ReEnableUAC) {Enable-UAC}
        $script:BoxstarterPassword=InitAutologon -RebootOk:$RebootOk $password
        $script:BoxstarterUser=$env:username
        $Boxstarter.RebootOk=$RebootOk
        $Boxstarter.ScriptToCall = Resolve-Script $ScriptToCall $scriptFile
        Stop-UpdateServices
        &([ScriptBlock]::Create($Boxstarter.ScriptToCall)) 2>&1 | Tee-BoxstarterLog
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

function Test-Admin {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

function Resolve-Script([ScriptBlock]$script, [string]$scriptFile){
    if($script) {return $script}
    if(Test-Path $scriptFile) {
        $script=(Get-Content $scriptFile)
        if($script.length -gt 0) {
            return [ScriptBlock]::Create($script)
        }
    }
    throw "No Script was specified to call."
}

function Test-ReEnableUAC {
    $test=Test-Path "$env:temp\BoxstarterReEnableUAC"
    if($test){del "$env:temp\BoxstarterReEnableUAC"}
    return $test
}