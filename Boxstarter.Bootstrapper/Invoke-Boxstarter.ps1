function Invoke-BoxStarter{
<#
.SYNOPSIS
Invokes the Boxstarter bootstrapper

.DESCRIPTION
This wraps any PowerShell script block and executes it in an environment tailored for uninterrupted installations
 - Turns off the windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.WinConfig module that provides functions for customizing windows
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under administrator permissions
If the password argument is not included and RebootOk is passed,
the user will be prompted for a password immediately after
invoking the command and that password will be used for any
subsequent reboot during the boxstarter run.

.Parameter ScriptToCall
The script that Boxstarter wraps. After Boxstarter shuts down
the update services and ensures that the console is running as
an administrator, it invokes this script. The script may call Invoke-Reboot
at any time and Boxstarter will ensure that the machine is
rebooted, logged in and the script is rerun.

.Parameter Password
This password will be used to automatically log the user in if a
reboot is required and reboots are enabled.

.Parameter RebootOk
If set, a reboot will be performed if boxstarter determines that a
reboot is pending. If no password is supplied to the Password
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

This invokes Boxstarter and invokes MyInstall. If pending
reboots are detected, boxstarter will restart the machine. Boxstarter
will prompt the user to enter a password which will be used for
automatic logins in the event a restart is required.

.LINK
https://boxstarter.org
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
      [switch]$NoPassword,

      [Parameter(Position=6,Mandatory=0)]
      [switch]$DisableRestart,

      [Parameter(Position=7,Mandatory=0)]
      [switch]$StopOnPackageFailure
    )
    $BoxStarter.IsRebooting = $false
    $scriptFile = "$(Get-BoxstarterTempDir)\boxstarter.script"
    if (!(Test-Admin)) {
        New-Item $scriptFile -type file -value $ScriptToCall.ToString() -force | Out-Null
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
        if (!(Get-IsRemote)) { 
            Write-BoxstarterLogo 
        }
        $session = Start-TimedSection "Installation session." -Verbose
        if($RebootOk){
            $Boxstarter.RebootOk = $RebootOk
        }
        if ($DisableRestart) {
            $Boxstarter.DisableRestart = $DisableRestart
        }
        if ($StopOnPackageFailure) {
            $Boxstarter.StopOnPackageFailure = $StopOnPackageFailure
        }
        if ($encryptedPassword) {
            $password = ConvertTo-SecureString -string $encryptedPassword
        }
        if (!$NoPassword) {
            Write-BoxstarterMessage "NoPassword is false checking autologin" -verbose
            $boxstarter.NoPassword = $False
            $script:BoxstarterPassword = InitAutologon $password
        }
        if ($script:BoxstarterPassword -eq $null) {
            $boxstarter.NoPassword = $True
        }
        Write-BoxstarterMessage "NoPassword is set to $($boxstarter.NoPassword) and RebootOk is set to $($Boxstarter.RebootOk) and the NoPassword parameter passed was $NoPassword and StopOnPackageFailure is set to $($Boxstarter.StopOnPackageFailure)" -verbose
        $Boxstarter.ScriptToCall = Resolve-Script $ScriptToCall $scriptFile
        Stop-UpdateServices
        &([ScriptBlock]::Create($Boxstarter.ScriptToCall))
        return $true
    }
    catch {
       Log-BoxStarterMessage ($_ | Out-String)
       throw $_
    }
    finally{
        Cleanup-Boxstarter -KeepWindowOpen:$KeepWindowOpen -DisableRestart:$DisableRestart
        Stop-TimedSection $session
        if($BoxStarter.IsRebooting) {
            RestartNow
        }
    }
}

function RestartNow {
    Write-BoxstarterMessage "Restart Required. Restarting now..."
    Restart-Computer -force -ErrorAction SilentlyContinue
}

function Read-AuthenticatedPassword {
    $attemptsLeft=3
    while(--$attemptsLeft -ge 0 -and !$val) {
        try{
            $Password=Read-Host -AsSecureString "Autologon Password"
            $currentUser=Get-CurrentUser
            $creds = New-Object System.Management.Automation.PsCredential("$($currentUser.Domain)\$($currentUser.Name)", $password)
            Start-Process "Cmd.exe" -argumentlist "/c","echo" -Credential $creds
            Write-BoxstarterMessage "Successfully authenticated password."
            return $password
        }
        catch { }
    }
    Write-BoxstarterMessage "Unable to authenticate password for $($currentUser.Domain)\$($currentUser.Name). Proceeding with autologon disabled"
    return $null
}

function InitAutologon([System.Security.SecureString]$password){
    $autologonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $winlogonProps = Get-ItemProperty -Path $autologonKey
    if($winlogonProps.AutoAdminLogon){$autoLogon=Get-ItemProperty -Path $autologonKey -Name "AutoAdminLogon"}
    if($autoLogon) {
        $autoLogon = $autoLogon.AutoAdminLogon
        if($autoLogon -gt 0) {
            try { $autoLogonCount=Get-ItemProperty -Path $autologonKey -Name "AutoLogonCount" -ErrorAction stop } catch {$global:error.RemoveAt(0)}
            if($autoLogonCount) {$autoLogon=$autoLogonCount.autoLogonCount}
        }
    } else {$autoLogon=0}
    $Boxstarter.AutologedOn = ($autoLogon -gt 0)
    Write-BoxstarterMessage "AutoLogin status is $($Boxstarter.AutologedOn)" -verbose
    if($Boxstarter.RebootOk -and !$Password -and !$Boxstarter.AutologedOn) {
        Write-BoxstarterMessage "Please type CTRL+C or close this window to exit Boxstarter if you do not want to risk a reboot during this Boxstarter install.`r`n" -nologo -Color Yellow
        Write-BoxstarterMessage @"
Boxstarter may need to reboot your system.
Please provide your password so that Boxstarter may automatically log you on.
Your password will be securely stored and encrypted.
"@ -nologo

        $Password=Read-AuthenticatedPassword
    }
    return $password
}

function Resolve-Script([ScriptBlock]$script, [string]$scriptFile){
    if($script) {return $script.ToString()}
    if(Test-Path $scriptFile) {
        $scriptFile=(Get-Content $scriptFile)
        if($scriptFile.length -gt 0) {
            return $scriptFile
        }
    }
    throw "No Script was specified to call."
}
