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
If the password argument is not included and RebootOk is passed, 
the user will be prompted for a password immediately after 
invoking the command and that password will be used for any 
subsequent reboot during the boxstarter run.

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
reboot is pending. If no password is supplied t othe Password 
parameterBoxstarter will prompt the user to enter a password which 
will be used for automatic logins in the event a restart is 
required.

.PARAMETER KeepWindowOpen
Enabling this switch will prevent the command window from closing and 
prompt the user to pres the Enter key before the window closes. This 
is ideal when not invoking boxstarter from a console.

.PARAMETER NoPassword
When set, Boxstarter will never prompt for logon. Use this if using
an account without password validation.

.EXAMPLE
Invoke-Boxstarter {Import-Modler myinstaller;Invoke-MyInstall} -RebootOk

This invokes boxstarter and iinvokes MyInstall. If pending 
reboots are detected, boxstarter will restart the machine. Boxstarter
will prompt the user to enter a password which will be used for 
automatic logins in the event a restart is required.

.LINK
http://boxstarter.codeplex.com
about_boxstarter_variable_in_bootstrapper
about_boxstarter_bootstrapper
Invoke-Reboot
#>    
    [CmdletBinding()]
    param(
      [Parameter(Position=0,Mandatory=0)]
      [ScriptBlock]$ScriptToCall,
      [Parameter(Position=1,Mandatory=0)]
      [System.Security.SecureString]$password,
      [Parameter(Position=2,Mandatory=0)]
      [switch]$RebootOk,
      [Parameter(Position=3,Mandatory=0)]
      [string]$encryptedPassword=$null,
      [Parameter(Position=4,Mandatory=0)]
      [switch]$KeepWindowOpen,
      [Parameter(Position=5,Mandatory=0)]
      [switch]$NoPassword      
    )
    $scriptFile = "$(Get-BoxstarterTempDir)\boxstarter.script"
    if(!(Test-Admin)) {
        New-Item $scriptFile -type file -value $ScriptToCall.ToString() -force | out-null
        Write-BoxstarterMessage "User is not running with administrative rights. Attempting to elevate..."
        $unNormalized=(Get-Item "$($Boxstarter.Basedir)\Boxstarter.Bootstrapper\BoxStarter.Bootstrapper.psd1")
        if($password){ 
            $encryptedPass = convertfrom-securestring -securestring $password
            $passwordArg = "-encryptedPassword $encryptedPass"
        }
        $command = "-ExecutionPolicy bypass -noexit -command Import-Module `"$($unNormalized.FullName)`";Invoke-BoxStarter $(if($RebootOk){'-RebootOk'}) $passwordArg"
        Start-Process powershell -verb runas -argumentlist $command
        return
    }
    $session=$null
    try{
        $boxMod=(IEX (Get-Content (join-path $Boxstarter.Basedir Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1) | Out-String))
        write-BoxstarterMessage "Boxstarter Version $($boxMod.ModuleVersion)" -nologo -Color White
        write-BoxstarterMessage "$($boxMod.Copyright) http://boxstarter.codeplex.com`r`n" -nologo -Color White
        $session=Start-TimedSection "Installation session."
        if($RebootOk){$Boxstarter.RebootOk=$RebootOk}
        if($encryptedPassword){$password = ConvertTo-SecureString -string $encryptedPassword}
        if(!$NoPassword){
            $boxstarter.NoPassword=$False
            $script:BoxstarterPassword=InitAutologon $password
        } 
        else {
            $boxstarter.NoPassword=$True
        }
        $script:BoxstarterUser=$env:username
        $Boxstarter.ScriptToCall = Resolve-Script $ScriptToCall $scriptFile
        Stop-UpdateServices
        &([ScriptBlock]::Create($Boxstarter.ScriptToCall))
    }
    catch {
       Log-BoxStarterMessage $_
       throw $_
    }
    finally{
        Cleanup-Boxstarter -KeepWindowOpen:$KeepWindowOpen
        Stop-TimedSection $session
        if($BoxStarter.IsRebooting) {
            $BoxStarter.IsRebooting = $false #reset
            RestartNow
        }
    }
}

function RestartNow {
    Write-BoxstarterMessage "Restarting..."
    Restart-Computer -force
}

function Read-AuthenticatedPassword {
    $attemptsLeft=3
    while(--$attemptsLeft -ge 0 -and !$val) {
        try{
            $Password=Read-Host -AsSecureString "Autologon Password"
            $creds = New-Object System.Management.Automation.PsCredential("$env:UserDomain\$env:username", $password)
            Start-Process "Cmd.exe" -argumentlist "/c","echo" -Credential $creds
            write-BoxstarterMessage "Succesfully authenticated password."
            return $password
        }
        catch { }
    }
    write-BoxstarterMessage "Unable to authenticate password. Proceeding with autologon disabled"
    return $null
}

function InitAutologon([System.Security.SecureString]$password){
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
    if($Boxstarter.RebootOk -and !$Password -and !$Boxstarter.AutologedOn) {
        Write-BoxstarterMessage "Please type CTRL+C or close this window to exit Boxstarter if you do not want to risk a reboot during this Boxstarter install.`r`n" -nologo -Color Yellow
        write-BoxstarterMessage @"
Boxstarter may need to reboot your system. 
Please provide your password so that Boxstarter may automatically log you on. 
Your password will be securely stored and encrypted.
"@ -nologo

        $Password=Read-AuthenticatedPassword
    }
    return $password
}

function Resolve-Script([ScriptBlock]$script, [string]$scriptFile){
    if($script) {return $script}
    if(Test-Path $scriptFile) {
        $scriptFile=(Get-Content $scriptFile)
        if($scriptFile.length -gt 0) {
            return [ScriptBlock]::Create($scriptFile)
        }
    }
    throw "No Script was specified to call."
}