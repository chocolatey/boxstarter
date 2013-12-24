function Install-BoxstarterPackage {
<#
.SYNOPSIS
Installs a Boxstarter package

.DESCRIPTION
This function must be run as administrator.

This function wraps a Chocolatey Install and provides these additional features
 - Installs chocolatey if it is not already installed
 - Installs the .net 4.5 framework if it is not installed which is a chocolatey requirement
 - Disables windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.WinConfig module that provides functions for customizing windows
 - Detects pending reboots and restarts the machine when necessary to avoid installation failures
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures everything runs under admin
 - Supports remote installations allowing packages to be installed on a remote machine

 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget
 This can be configured by editing $($Boxstarter.BaseDir)\Boxstarter.Config

 If the package name provided is a URL or resolves to a file, then 
 it is assumed that this contains the chocolatey install script and
 a .nupkg file will be created using the script.

 Boxstarter can install packages onto a remote machine. To accomplish this,
 use either the ComputerName, Session or ConnectionURI parameters. Boxstarter uses
 powershell remoting to establish an iteractive session on the remote computer.
 Boxstarter configures all the necessary client side remoting settings necessary if 
 they are not already configured. Boxstarter will prompt the user to verify that 
 this is ok. Using the -Force switch will suppress the prompt. Boxstarter also ensures
 that CredSSP authentication is enabled so that any network calls made by a package will 
 forward the users credentials.

 Powershell Remoting must be enabled on the target machine in order to establish a connection. 
 If that machine's WMI ports are accesible, Boxstarter can enable powershell remoting 
 on the remote machine on its own. Otherwise, it can be manually enabled by entering 

 Enable-PSRemoting -Force

 In an administrative powershell console on the remote machine.
 
 .PARAMETER ComputerName
 If provided, Boxstarter will install the specified package name on all computers.
 Boxstarter will create a Remote Session on each computer using the Credentials 
 given in the Credential parameter.

 .PARAMETER ConnectionURI
 Specifies one or more Uniform Resource Identifiers (URI) that Boxstarter will use 
 to establish a connection with the remote computers upon which the pakage should 
 be installed. Use this parameter if you need to use a non default PORT or SSL.

 .PARAMETER Session
 If provided, Boxstarter will install the specified package in all given Windows 
 PowerShell sessions. Note that these sessions may be closed by the time 
 Install-BoxstarterPackage finishes. If Boxstarter needs to restart the remote 
 computer, the session will be discarded and a new session will be created using 
 the ConnectionURI of the original sesion.

 .PARAMETER BoxstarterConnectionConfig
 If provided, Boxstarter will install the specified package name on all computers
 inclused in the BoxstarterConnectionConfig. This object contains a ComputerName
 and a PSCredential. Use this objsct if you need to pass different computers
 requiring different credentials.

 .PARAMETER PackageName
 The name of a NugetPackage to be installed or a URI or 
 file path pointing to a chocolatey script. If using a package name,
 the .nupkg file for the provided package name is searched in the 
 following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

.PARAMETER DisableReboots
If set, reboots are suppressed.

.PARAMETER Credential
The credentials to use for auto logins after reboots. If installing on
a remote machine, ths credential will also be used to establish the 
connecion to the remote machine and also for any scheduled task that
boxstarter needs to create and run under a local context.

.PARAMETER KeepWindowOpen
Enabling this switch will prevent the command window from closing and 
prompt the user to pres the Enter key before the window closes. This 
is ideal when not invoking boxstarter from a console.

.Parameter Localrepo
This is the path to the local boxstarter repository where boxstarter 
should look for .nupkg files to install. By default this is located 
in the BuildPackages directory just under the root Boxstarter 
directory but can be changed with Set-BoxstarterConfig.

.NOTES
When establishing a remote connection, Boxstarter uses CredSSP 
authentication so that the session can access any network resources 
normally accesible to the Credential. If necessary, Boxstarter 
configures CredSSP authentication on both the local and remote 
machines as well as the necessary Group Policy and WSMan settings 
for credential delegation. When the installation completes, 
Boxstarter rolls back all settings that it changed to their original 
state.

When using a Windows PowerShell session instead of ComputerName or 
ConnectionURI, Boxstarter will use the authenticaion mechanism of the 
existing session and will not configure CredSSP if the session provided 
is not using CredSSP. If the session is not using CredSSP, it may be 
denied access to network resources normally accesble to the Credential 
being used. If you do need to access network resources external to the 
session, you should use CredSSP when establishing the connection.

.INPUTS
ComputerName, ConnrectionURI and Session may all be specified on the 
pipeline.

.OUTPUTS
Returns a PSObject for each session, ComputerName or ConnectionURI or a 
single PSObject for local installations. The PSObject has the following 
properties:

ComputerName: The name of the computer where the package was installed

StartTime: The time that the installation began

FinishTime: The time that Boxstarter finished the installation

Completed: True or False indicating if Boxstarter was able to complete 
the installation without a terminating exception interrupting the install. 
Even if this value is True, it does not mean that all componebts installed 
in the package succeeded. Boxstarter will not terminate an installation if 
individual Chocolatey packages fail. Use the Errors property to discover 
errors that were raised throughout the installation.

Errors: An array of all errors encountered during the duration of the 
installaion.

.EXAMPLE
Invoke-ChocolateyBoxstarter example

This installs the example .nupkg. If pending 
reboots are detected, boxstarter will restart the machine. Boxstarter
will not perform automatic logins after restart since no Credential
was given.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -Package https://gist.github.com/mwrock/6771863/raw/b579aa269c791a53ee1481ad01711b60090db1e2/gistfile1.txt `
   -Credential $cred

This installs the script uploaded to the github gist. The credentials
of the user mwrock are used to automatically login the user if 
boxstarter needs to reboot the machine.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ComputerName MyOtherComputer.mydomain.com -Package MyPackage -Credential $cred

This installs the MyPackage package on MyOtherComputer.mydomain.com.

.EXAMPLE
$cred=Get-Credential mwrock
$session=New-PSSession SomeComputer -Credential $cred
Install-BoxstarterPackage -Session $session -Package MyPackage -Credential $cred

This installs the MyPackage package on an existing session established with 
SomeComputer. A Credential is still passed to Boxstarter even though it is 
also used to establish the session because Boxstarter will need it for logons
and creating Scheduled Tasks on SomeComputer. If Boxstarter does need to 
reboot SomeComputer, it will need to create a new session after SomeComputer
has rebooted and then $session will no longer be in an Available state when
Install-BoxstarterPackage completes.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ConnectionURI http://RemoteComputer:59876/wsman -Package MyPackage -Credential $cred

This installs the MyPackage package on RemoteComputer which does not
listen on the default wsman port but has been configured to listen 
on port 59876.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ComputerName MyOtherComputer.mydomain.com -Package MyPackage -Credential $cred -Force

This installs the MyPackage package on MyOtherComputer.mydomain.com.
Becauce the -Force parameter is used, Boxstarter will not prompt the
user to confirm that it is ok to enable Powershell remoting if it is 
not already enabled. It will attempt to enable it without prompts.

.EXAMPLE
$cred=Get-Credential mwrock
"computer1","computer2" | Install-BoxstarterPackage -Package MyPackage -Credential $cred -Force

This installs the MyPackage package on computer1 and computer2
Becauce the -Force parameter is used, Boxstarter will not prompt the
user to confirm that it is ok to enable Powershell remoting if it is 
not already enabled. It will attempt to enable it without prompts.

Using -Force is especially advisable when installing packages on multiple 
computers because otherwise, if one computer is not accesible, the command 
will prompt the user if it is ok to try and confiure the computer before 
proceeding to the other computers.

.EXAMPLE
$cred1=Get-Credential mwrock
$cred2=Get-Credential domain\mwrock
(New-Object -TypeName BoxstarterConnectionConfig -ArgumentList "computer1",$cred1), `
(New-Object -TypeName BoxstarterConnectionConfig -ArgumentList "computer2",$cred2) |
Install-BoxstarterPackage -Package MyPackage

This installs the MyPackage package on computer1 and computer2 and uses
different credentials for each computer.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage script.ps1 -Credential $cred

This installs the script located at script.ps1 
in the command line's current directory.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage \\server\share\script.ps1 -Credential $cred

This invokes boxstarter and installs the script located at the 
specified share.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage win8Install -LocalRepo \\server\share\boxstarter -Credential $cred

This installs the Win8Install .nupkg. Boxstarter will look 
for the Win8Install .nupkg file in the \\serer\share\boxstarter 
directory.


.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
#>
    [CmdletBinding(DefaultParameterSetName="Package")]
	param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="BoxstarterConnectionConfig")]
        [BoxstarterConnectionConfig[]]$BoxstarterConnectionConfig,
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="ComputerName")]
        [string[]]$ComputerName,
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="ConnectionUri")]
        [Uri[]]$ConnectionUri,
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="Session")]
        [System.Management.Automation.Runspaces.PSSession[]]$Session,
        [parameter(Mandatory=$true, Position=0, ParameterSetName="Package")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="ComputerName")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="ConnectionUri")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="Session")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="BoxstarterConnectionConfig")]
        [string]$PackageName,
        [Management.Automation.PsCredential]$Credential,
        [switch]$Force,
        [switch]$DisableReboots,
        [parameter(ParameterSetName="Package")]
        [switch]$KeepWindowOpen,
        [string]$LocalRepo        
    )
    $CurrentVerbosity=$global:VerbosePreference
    try {

        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }

        #If no psremoting based params are present, we just run locally
        if($PsCmdlet.ParameterSetName -eq "Package"){
            Invoke-Locally @PSBoundParameters
            return
        }

        #me me me!
        Write-BoxstarterLogo
        
        #Convert pipeline to array
        $list=@($input)
        if($list.Count){
            Set-Variable -Name $PsCmdlet.ParameterSetName -Value $list
        }

        ##Cannot run remotely unelevated. Look into self elevating
        if(!(Test-Admin)) {
            Write-Error "You must be running as an administrator. Please open a Powershell console as Administrator and rerun Install-BoxstarperPackage."
            return
        }

        $sessionArgs=@{}
        if($Credential){
            $sessionArgs.Credential=$Credential
        }

        #If $sessions are being provided we assume remoting is setup on both ends
        #and dont need to test, configure and tear down
        if($Session -ne $null){
            Process-Sessions $Session $sessionArgs
            return
        }

        #We need the computernames to configure remoting
        if(!$ComputerName){
            $ComputerName = Get-ComputerNames $ConnectionUri $BoxstarterConnectionConfig
        }

        try{
            #Enable remoting settings if necessary on client
            $ClientRemotingStatus=Enable-BoxstarterClientRemoting $ComputerName

            #If unable to enable remoting on the client, abort
            if(!$ClientRemotingStatus.Success){return}

            $CredSSPStatus=Enable-BoxstarterCredSSP $ComputerName

            if($ConnectionURI){
                $ConnectionUri | %{
                    $sessionArgs.ConnectionURI = $_
                    Install-BoxstarterPackageOnComputer $_.Host $sessionArgs $PackageName $DisableReboots
                }
            }
            elseif($BoxstarterConnectionConfig) {
                $BoxstarterConnectionConfig | %{
                    $sessionArgs.ComputerName = $_.ComputerName
                    if($_.Credential){
                        $sessionArgs.Credential = $_.Credential
                    }
                    Install-BoxstarterPackageOnComputer $_.ComputerName $sessionArgs $PackageName $DisableReboots
                }
            }
            else {
                $ComputerName | %{
                    $sessionArgs.ComputerName = $_
                    Install-BoxstarterPackageOnComputer $_ $sessionArgs $PackageName $DisableReboots
                }
            }
        }
        finally{
            #Client settings should be as they were when we started
            Rollback-ClientRemoting $ClientRemotingStatus $CredSSPStatus
        }
    }
    finally{
        $global:VerbosePreference=$CurrentVerbosity
    }
}

function Get-ComputerNames($ConnectionUris, $BoxstarterConnectionConfigs) {
    $computerNames = @()

    if($ConnectionURIs){
        $ConnectionUris | %{
            $computerNames+=$_.Host
        }
    }

    if($BoxstarterConnectionConfigs){
        $BoxstarterConnectionConfigs | %{
            $computerNames+=$_.ComputerName
        }
    }

    return $computerNames
}

function Process-Sessions($sessions, $sessionArgs){
    $Sessions | %{
        Write-BoxstarterMessage "Processing Session..." -Verbose
        Set-SessionArgs $_ $sessionArgs
        $record = Start-Record $_.ComputerName
        try {
            if(-not (Install-BoxstarterPackageForSession $_ $PackageName $DisableReboots $sessionArgs)){
                $record.Completed=$false
            }
        }
        catch {
            $record.Completed=$false
        }
        finally{
            Finish-Record $record
        }
    }
}

function Start-Record($computerName) {
    $global:error.Clear()
    $props = @{
        StartTime = Get-Date
        Completed = $true
        ComputerName = $computerName
        Errors = @()
        FinishTime = $null
    }
    return (New-Object PSObject –Prop $props)
}

function Finish-Record($obj) {
    $obj.FinishTime = Get-Date
    $global:error | %{
        if($_.CategoryInfo -ne $null -and $_.CategoryInfo.Category -eq "OperationStopped"){
            Log-BoxstarterMessage $_
        }
        else {
            $obj.Errors += $_
        }
    }
    Write-Output $obj
}

function Install-BoxstarterPackageOnComputer ($ComputerName, $sessionArgs, $PackageName, $DisableReboots){
    $record = Start-Record $ComputerName
    try {
        if(!(Enable-RemotingOnRemote $ComputerName $sessionArgs.Credential)){
            Write-Error "Unable to access remote computer via Powershell Remoting or WMI. You can enable it by running: Enable-PSRemoting -Force from an Administrator Powershell console on the remote computer."
            $record.Completed=$false
            return
        }
        $enableCredSSP = Should-EnableCredSSP $sessionArgs $computerName

        $session = New-PSSession @sessionArgs -Name Boxstarter

        if(-not (Install-BoxstarterPackageForSession $session $PackageName $DisableReboots $sessionArgs $enableCredSSP)){
            $record.Completed=$false
        }
    }
    catch {
        $record.Completed=$false
    }
    finally{
        Finish-Record $record
    }
}

function Install-BoxstarterPackageForSession($session, $PackageName, $DisableReboots, $sessionArgs, $enableCredSSP) {
    try{
        if($session.Availability -ne "Available"){
            write-Error (New-Object -TypeName ArgumentException -ArgumentList "The Session is not Available")
            return $false
        }

        for($count = 1; $count -le 5; $count++) {
            try {
                Write-BoxstarterMessage "Attempt #$count to copy Boxstarter modules to $($session.ComputerName)" -Verbose
                Setup-BoxstarterModuleAndLocalRepo $session
                break
            }
            catch {
                if($global:Error.Count -gt 0){$global:Error.RemoveAt(0)}
                if($count -eq 5) { throw $_ }
            }
        }

        if($enableCredSSP){
            if($session){ Remove-PSSession $session -ErrorAction SilentlyContinue }
            $session = Enable-RemoteCredSSP $sessionArgs
        }
        
        Invoke-Remotely $session $PackageName $DisableReboots $sessionArgs
        return $true
    }
    finally {
        if($sessionArgs.Authentication){
            $sessionArgs.Remove("Authentication")
        }
        if($enableCredSSP){
            Disable-RemoteCredSSP $sessionArgs
        }
        if($session -ne $null -and $session.Name -eq "Boxstarter") {
            Remove-PSSession $Session
            $Session = $null
        }
    }
}

function Invoke-Locally {
    param(
        [string]$PackageName,
        [Management.Automation.PsCredential]$Credential,
        [switch]$Force,
        [switch]$DisableReboots,
        [switch]$KeepWindowOpen
    )
    if($PSBoundParameters.ContainsKey("Credential")){
        $PSBoundParameters.Add("Password",$PSBoundParameters["Credential"].Password)
        $PSBoundParameters.Remove("Credential") | out-Null
    }
    else {
        $PSBoundParameters.Add("NoPassword",$True)
    }
    if($PSBoundParameters.ContainsKey("Force")){
        $PSBoundParameters.Remove("Force") | out-Null
    }
    $PSBoundParameters.Add("BootstrapPackage", $PSBoundParameters.PackageName)
    $PSBoundParameters.Remove("PackageName") | out-Null

    $record = Start-Record 'localhost'
    try {
        Invoke-ChocolateyBoxstarter @PSBoundParameters | Out-Null
    }
    catch {
        $record.Completed=$false
        throw
    }
    finally{
        Finish-Record $record
    }
}

function Enable-RemotingOnRemote ($ComputerName, $Credential){
    Write-BoxstarterMessage "Testing remoting access on $ComputerName..."
    try { 
        $remotingTest = Invoke-Command $ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction Stop
    }
    catch {
        $ex=$_
        $global:error.RemoveAt(0)
    }
    if($remotingTest -eq $null){
        Write-BoxstarterMessage "Powershell Remoting is not enabled or accesible on $ComputerName" -Verbose
        $wmiTest=Invoke-WmiMethod -ComputerName $ComputerName -Credential $Credential Win32_Process Create -Args "cmd.exe" -ErrorAction SilentlyContinue
        if($wmiTest -eq $null){
            $global:error.RemoveAt(0)
            return $false
        }
        if($Force -or (Confirm-Choice "Powershell Remoting is not enabled on Remote computer. Should Boxstarter enable powershell remoting?")){
            Write-BoxstarterMessage "Enabling Powershell Remoting on $ComputerName"
            Enable-RemotePSRemoting $ComputerName $Credential
        }
        else {
            Write-BoxstarterMessage "Not enabling local Powershell Remoting on $ComputerName. Aborting package install"
            return $False
        }
    }
    else {
        Write-BoxstarterMessage "Remoting is accesible on $ComputerName"
    }
    return $True
}

function Setup-BoxstarterModuleAndLocalRepo($session){
    if($LocalRepo){$Boxstarter.LocalRepo=$LocalRepo}
    Write-BoxstarterMessage "Copying Boxstarter Modules and local repo packages at $($Boxstarter.BaseDir) to $env:temp on $($Session.ComputerName)..."
    Invoke-Command -Session $Session { mkdir $env:temp\boxstarter\BuildPackages -Force  | out-Null }
    Send-File "$($Boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.zip" "Boxstarter\boxstarter.zip" $session
    Get-ChildItem "$($Boxstarter.LocalRepo)\*.nupkg" | % { 
        Write-BoxstarterMessage "Copying $($_.Name) to $($Session.ComputerName)" -Verbose
        Send-File "$($_.FullName)" "Boxstarter\BuildPackages\$($_.Name)" $session 
    }
    Invoke-Command -Session $Session {
        Set-ExecutionPolicy Bypass -Force
        $shellApplication = new-object -com shell.application 
        $zipPackage = $shellApplication.NameSpace("$env:temp\Boxstarter\Boxstarter.zip") 
        $destinationFolder = $shellApplication.NameSpace("$env:temp\boxstarter") 
        $destinationFolder.CopyHere($zipPackage.Items(),0x10)
        [xml]$configXml = Get-Content (Join-Path $env:temp\Boxstarter BoxStarter.config)
        if($configXml.config.LocalRepo -ne $null) {
            $configXml.config.RemoveChild(($configXml.config.ChildNodes | ? { $_.Name -eq "LocalRepo"}))
            $configXml.Save((Join-Path $env:temp\Boxstarter BoxStarter.config))
        }
        Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
    }
}

function Invoke-RemoteBoxstarter($Package, $Password, $DisableReboots) {
    $remoteResult = Invoke-Command -session $session {
        param($SuppressLogging,$pkg,$password,$DisableReboots, $verbosity)
        $global:VerbosePreference=$verbosity
        Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
        $Boxstarter.SuppressLogging=$SuppressLogging
        $result=$null
        try {
            $result = Invoke-ChocolateyBoxstarter $pkg -Password $password -DisableReboots:$DisableReboots
            if($Boxstarter.IsRebooting){
                return @{Result="Rebooting"}
            }
            if($result=$true){
                return @{Result="Completed"}
            }
        }
        catch{
            throw
        }
    } -ArgumentList $Boxstarter.SuppressLogging, $Package, $Password, $DisableReboots, $global:VerbosePreference
    Write-BoxstarterMessage "Result from Remote Boxstarter: $($remoteResult.Result)" -Verbose
    return $remoteResult
}

function Test-RebootingOrDisconnected($RemoteResult) {
    if($remoteResult -eq $null -or $remoteResult.Result -eq $null -or $remoteResult.Result -eq "Rebooting") {
        return $true
    }
    else {
        return $false
    }
}

function Wait-ForSessionToClose($session) {
    Write-BoxstarterMessage "Waiting for $($session.ComputerName) to sever remote session..."
    $timeout=0
    while($session.State -eq "Opened" -and $timeout -lt 120){
        $timeout += 2
        start-sleep -seconds 2
    }
}

function Test-ShutDownInProgress($Session) {
    $response=Invoke-Command -Session $Session { 
        $systemMetrics = Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SystemMetrics
{
    private const int SM_SHUTTINGDOWN = 0x2000;

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int smIndex);

    public static bool IsShuttingdown() 
    {
        return (GetSystemMetrics(SM_SHUTTINGDOWN) != 0);
    }

}
'@ -PassThru
        return $systemMetrics::IsShuttingdown()
    }

    if($response -eq $false) {
        Write-BoxstarterMessage "System Shutdown not in progress" -Verbose
    }
    else {
        Write-BoxstarterMessage "System Shutdown in progress" -Verbose
    }

    return $response
}

function Test-Reconnection($Session, $sessionPID) {
    $reconnected = $false

    #If there is a pending reboot then session is in the middle of a restart
    $response=Invoke-Command -Session $session { 
        Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1 
        return Test-PendingReboot
    } -ErrorAction SilentlyContinue
    Write-BoxstarterMessage "Reboot check returned $response" -Verbose


    if($response -ne $null -and $response -eq $false){
        #Check for a system shutdown in progress
        $response = Test-ShutDownInProgress $session

        if($response -eq $false) {
            $reconnected = $true #Session is connectable
            try{
                #In case previou session's task is still alive kill it so itr does not lock anything
                Write-BoxstarterMessage "Killing $sessionPID" -Verbose
                Invoke-Command -Session $session { 
                    param($p)
                    if(Get-Process -Id $p -ErrorAction SilentlyContinue){
                        KILL $p -ErrorAction Stop -Force
                    }
                    else {
                        $global:Error.RemoveAt(0)
                    }
                } -ArgumentList $sessionPID
            } catch{
                Write-BoxstarterMessage "Failed to kill $sessionPID : $($global:Error[0])" -Verbose
                $global:Error.RemoveAt(0)
            }
        }
    }
    #if the session is pending a reboot but not in the middle of a system shutdown, 
    #try to invoke a reboot to prevent us from hanging while waiting
    elseif($response -eq $true){
        Write-BoxstarterMessage "Attempting to restart $($session.ComputerName)" -Verbose
        Invoke-Command -Session $session { 
            Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1 
            $Boxstarter.RebootOK=$true
            if(Test-PendingReboot){Invoke-Reboot}
        } -ErrorAction SilentlyContinue
    }

    return $reconnected
}

function Invoke-Remotely($session,$Package,$DisableReboots,$sessionArgs){
    while($session.Availability -eq "Available") {
        $sessionPID = Invoke-Command -Session $session { return $PID }
        $remoteResult = Invoke-RemoteBoxstarter $Package $sessionArgs.Credential.Password $DisableReboots

        if(Test-RebootingOrDisconnected $remoteResult) {
            Wait-ForSessionToClose $session

            $reconnected=$false
            Write-BoxstarterMessage "Waiting for $($session.ComputerName) to respond to remoting..."
            Do{
                if($session -ne $null){
                    Remove-PSSession $session
                    $session = $null
                }
                $response=$null
                start-sleep -seconds 2
                $session = New-PSSession @sessionArgs -Name Boxstarter -ErrorAction SilentlyContinue
                if($session -eq $null) {
                    $global:Error.RemoveAt(0)
                }
                elseif($session -ne $null -and $Session.Availability -eq "Available"){
                    if($remoteResult.Result -eq "Rebooting"){$sessionPID=-1}
                    $reconnected = Test-Reconnection $session $sessionPID
                }
            }
            Until($reconnected -eq $true)
        }
        else {
            break
        }
    }
}

function Set-SessionArgs($session, $sessionArgs) {
    $uri = try { Invoke-Command $session {return $PSSenderInfo.ConnectionString} -ErrorAction SilentlyContinue } catch{}
    if($uri){
        $sessionArgs.ConnectionURI=$uri
    }
    else{
        $sessionArgs.ComputerName=$session.ComputerName
    }    
}

function Should-EnableCredSSP($sessionArgs, $computerName) {
    Write-BoxstarterMessage "Testing remote CredSSP..." -Verbose
    if($sessionArgs.Credential){
        $uriArgs=@{}
        if($sessionArgs.ConnectionURI){
            $uri = [URI]$sessionArgs.ConnectionURI
            $uriArgs = @{Port=$uri.port;UseSSL=($uri.scheme -eq "https")}
        }
        try {
            $credsspEnabled = Test-WsMan -ComputerName $ComputerName @uriArgs -Credential $SessionArgs.Credential -Authentication CredSSP -ErrorAction SilentlyContinue 
        } 
        catch {
            Write-BoxstarterMessage "Exception from testing WSMan for CredSSP access" -Verbose
            $xml=[xml]$_
            if($xml -ne $null) {
                Write-BoxstarterMessage "WSMan Fault Found" -Verbose
                Write-BoxstarterMessage "$($xml.OuterXml)" -Verbose
            }
            else {
                Write-BoxstarterMessage $_ -Verbose
            }
        }
        if($credsspEnabled -eq $null){
            Write-BoxstarterMessage "Need to enable credssp on server" -Verbose
            if($global:Error.Count -gt 0){ $global:Error.RemoveAt(0) }
            return $True
        }
        else{
            Write-BoxstarterMessage "CredSSP test response:" -Verbose
            [System.Xml.XmlElement]$xml=$credsspEnabled
            if($xml -ne $null) {
                Write-BoxstarterMessage "WSMan XML Found..." -Verbose
                Write-BoxstarterMessage "$($xml.OuterXml)" -Verbose
            }
            $sessionArgs.Authentication="CredSSP"
        }
    }
    Write-BoxstarterMessage "Do not need to enable credssp on server" -Verbose
    return $false
}

function Enable-RemoteCredSSP($sessionArgs) {
    Write-BoxstarterMessage "Creating a scheduled task to enable CredSSP Authentication on $ComputerName..."
    Invoke-RetriableScript {
        $splat=$args[0]
        Invoke-Command @splat { 
            param($Credential)
            Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
            Create-BoxstarterTask $Credential
            Invoke-FromTask "Enable-WSManCredSSP -Role Server -Force | out-Null"
            Remove-BoxstarterTask
        } -ArgumentList $Args[0].Credential -ErrorAction Stop
    } $sessionArgs
    $sessionArgs.Authentication="CredSSP"
    Write-BoxstarterMessage "Creating New session with CredSSP Auth..." -Verbose
    $session = Invoke-RetriableScript {
        $splat=$args[0]
        $s = New-PSSession @splat -Name Boxstarter -ErrorAction Stop 
        return $s
    } $sessionArgs
    return $session
}

function Disable-RemoteCredSSP ($sessionArgs){
    Write-BoxstarterMessage "Disabling CredSSP Authentication on $ComputerName" -Verbose
    Invoke-Command @sessionArgs { 
        param($Credential)
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        Invoke-FromTask "Disable-WSManCredSSP -Role Server | Out-Null"
        Remove-BoxstarterTask
    } -ArgumentList $sessionArgs.Credential
}

function Rollback-ClientRemoting($ClientRemotingStatus, $CredSSPStatus) {
    Write-BoxstarterMessage "Rolling back remoting settings changed by Boxstarter..."
    if($ClientRemotingStatus.PreviousTrustedHosts -ne $null){
        Write-BoxstarterMessage "Reseting wsman Trusted Hosts to $($ClientRemotingStatus.PreviousTrustedHosts)" -Verbose
        Set-Item "wsman:\localhost\client\trustedhosts" -Value "$($ClientRemotingStatus.PreviousTrustedHosts)" -Force
    }
    if($CredSSPStatus -ne $null -and $CredSSPStatus.Success){
        try {Disable-WSManCredSSP -Role Client -ErrorAction SilentlyContinue } catch{ Write-BoxstarterMessage "Unable to disable CredSSP locally" }
        if($CredSSPStatus.PreviousCSSPTrustedHosts -ne $null){
            try{
                Write-BoxstarterMessage "Reseting CredSSP Trusted Hosts to $($CredSSPStatus.PreviousCSSPTrustedHosts.Replace('wsman/',''))" -Verbose
                Enable-WSManCredSSP -DelegateComputer $CredSSPStatus.PreviousCSSPTrustedHosts.Replace("wsman/","") -Role Client -Force | Out-Null
            }
            catch{}
        }
        Write-BoxstarterMessage "Reseting GroupPolicy for Credentials Delegation" -Verbose
        if(Test-Path "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly") {
            (Get-Item "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property | % {
                if([int]$_ -gt $CredSSPStatus["PreviousFreshNTLMCredDelegationHostCount"]) {
                    Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name $_
                }
            }
        }

        if(Test-Path "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials") {
            (Get-Item "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials").Property | % {
                if([int]$_ -gt $CredSSPStatus["PreviousFreshCredDelegationHostCount"]) {
                    Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials" -Name $_
                }
            }
        }
    }
}