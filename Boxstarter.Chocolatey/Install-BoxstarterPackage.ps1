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
 
 .PARAMETER PackageName
 The name of a NugetPackage to be installed or a URI or 
 file path pointing to a chocolatey script. If using a package name,
 the .nupkg file for the provided package name is searched in the 
 following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The chocolatey feed
 - The boxstarter feed on myget

 #TODO:
    - Add help docs for remote parameters
    - add an example or two
    - A notes about psobject output
    - Clarify "Simply chocolatey" in docs
    - Clarify Package From script
    - Add docs about pipeline and output
    - Test on win7 to 2 computers
    - test from locl to 2 vms

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
        [string]$PackageName,
        [Management.Automation.PsCredential]$Credential,
        [switch]$Force,
        [switch]$DisableReboots,
        [parameter(ParameterSetName="Package")]
        [switch]$KeepWindowOpen,
        [string]$LocalRepo        
    )

    #If no psremoting based params are present, we just run locally
    if($PsCmdlet.ParameterSetName -eq "Package"){
        Invoke-Locally @PSBoundParameters
        return
    }

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
        $Session | %{
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
        return
    }

    #We need the computernames to configure remoting
    if($ConnectionURI){
        $ConnectionUri | %{
            $computerName+=$_.Host
        }
    }

    try{
        #Enable remoting settings if necessary on client
        $ClientRemotingStatus=Enable-BoxstarterClientRemoting $ComputerName

        #If unable to enable remoting on the client, abort
        if(!$ClientRemotingStatus.Success){return}

        if($ConnectionURI){
            $ConnectionUri | %{
                $sessionArgs.ConnectionURI = $_
                Install-BoxstarterPackageOnComputer $_.Host $sessionArgs $PackageName $DisableReboots
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
        Rollback-ClientRemoting $ClientRemotingStatus
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
        $obj.Errors += $_
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

        Setup-BoxstarterModuleAndLocalRepo $session

        if($enableCredSSP){
            if($session){ Remove-PSSession $session -ErrorAction SilentlyContinue }
            $session = Enable-RemoteCredSSP $sessionArgs
        }
        
        Invoke-Remotely $session $PackageName $DisableReboots $sessionArgs
        return $true
    }
    finally {
        if($enableCredSSP){
            Disable-RemoteCredSSP $sessionArgs
        }
        if($sessionArgs.Authentication){
            $sessionArgs.Remove("Authentication")
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
        Invoke-ChocolateyBoxstarter @PSBoundParameters
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
    Write-BoxstarterMessage "Testing remoting access on $ComputerName"
    try { 
        $remotingTest = Invoke-Command $ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction Stop
    }
    catch {
        $ex=$_
    }
    if($remotingTest -eq $null){
        Write-BoxstarterMessage "Powershell Remoting is not enabled or accesible on $ComputerName"
        $wmiTest=Invoke-WmiMethod -Computer $ComputerName -Credential $Credential Win32_Process Create -Args "cmd.exe" -ErrorAction SilentlyContinue
        if($wmiTest -eq $null){
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
    Write-BoxstarterMessage "Copying Boxstarter Modules at $($Boxstarter.LocalRepo) to $env:temp on $($Session.ComputerName)"
    Invoke-Command -Session $Session { mkdir $env:temp\boxstarter\BuildPackages -Force  | out-Null }
    Send-File "$($Boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.zip" "Boxstarter\boxstarter.zip" $session
    Get-ChildItem "$($Boxstarter.LocalRepo)\*.nupkg" | % { 
        Write-BoxstarterMessage "Copying $($_.Name) to $($Session.ComputerName)"
        Send-File "$($_.FullName)" "Boxstarter\BuildPackages\$($_.Name)" $session 
    }
    Invoke-Command -Session $Session {
        Set-ExecutionPolicy Bypass -Force
        $shellApplication = new-object -com shell.application 
        $zipPackage = $shellApplication.NameSpace("$env:temp\Boxstarter\Boxstarter.zip") 
        $destinationFolder = $shellApplication.NameSpace("$env:temp\boxstarter") 
        $destinationFolder.CopyHere($zipPackage.Items(),0x10)
        Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
    }
}

function Invoke-Remotely($session,$Package,$DisableReboots,$sessionArgs){
    while($session.Availability -eq "Available") {
        $remoteResult = Invoke-Command -session $session {
            param($possibleResult,$SuppressLogging,$pkg,$password,$DisableReboots)
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
        } -ArgumentList $possibleResult, $Boxstarter.SuppressLogging, $Package, $sessionArgs.Credential.Password, $DisableReboots
        
        Write-Debug "Result from Remote Boxstarter: $($remoteResult.Result)"
        if($remoteResult -eq $null -or $remoteResult.Result -eq $null -or $remoteResult.Result -eq "Rebooting") {
            Write-BoxstarterMessage "Waiting for $($session.ComputerName) to sever remote session..."
            $timeout=0
            while($session.State -eq "Opened" -and $timeout -lt 120){
                $timeout += 2
                start-sleep -seconds 2
            }
            $reconnected=$false
            Write-BoxstarterMessage "Waiting for $($session.ComputerName) to respond to remoting..."
            Remove-PSSession $session
            Do{
                $response=$null
                start-sleep -seconds 2
                $session = New-PSSession @sessionArgs -Name Boxstarter -ErrorAction SilentlyContinue
                if($session -ne $null -and $Session.Availability -eq "Available"){
                    $response=Invoke-Command @sessionArgs { Get-WmiObject Win32_ComputerSystem } -ErrorAction SilentlyContinue
                    if($response -ne $null){
                        $reconnected = $true
                    }
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
    if($sessionArgs.Credential){
        $uriArgs=@{}
        if($sessionArgs.ConnectionURI){
            $uri = [URI]$sessionArgs.ConnectionURI
            $uriArgs = @{Port=$uri.port;UseSSL=($uri.scheme -eq "https")}
        }
        try {$credsspEnabled = Test-WsMan -ComputerName $ComputerName @uriArgs -Credential $SessionArgs.Credential -Authentication CredSSP -ErrorAction SilentlyContinue } catch {}
        if($credsspEnabled -eq $null){
            return $True
        }
        elseif($credsspEnabled -ne $null){
            $sessionArgs.Authentication="CredSSP"
        }
    }
    return $false
}

function Enable-RemoteCredSSP($sessionArgs) {
    Write-BoxstarterMessage "Enabling CredSSP Authentication on $ComputerName"
    Invoke-Command @sessionArgs { 
        param($Credential)
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        Invoke-FromTask "Enable-WSManCredSSP -Role Server -Force | out-Null" 
    } -ArgumentList $sessionArgs.Credential
    $sessionArgs.Authentication="CredSSP"
    return New-PSSession @sessionArgs -Name Boxstarter
}

function Disable-RemoteCredSSP ($sessionArgs){
    Write-BoxstarterMessage "Disabling CredSSP Authentication on $ComputerName"
    Invoke-Command @sessionArgs { 
        param($Credential)
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        Invoke-FromTask "Disable-WSManCredSSP -Role Server | Out-Null"
        Remove-BoxstarterTask
    } -ArgumentList $sessionArgs.Credential
}

function Rollback-ClientRemoting($ClientRemotingStatus) {
    if($ClientRemotingStatus -ne $null -and $ClientRemotingStatus.Success){
        Disable-WSManCredSSP -Role Client
        if($ClientRemotingStatus.PreviousCSSPTrustedHosts -ne $null){
            try{
                Write-BoxstarterMessage "Reseting CredSSP Trusted Hosts to $($ClientRemotingStatus.PreviousCSSPTrustedHosts.Replace('wsman/',''))"
                Enable-WSManCredSSP -DelegateComputer $ClientRemotingStatus.PreviousCSSPTrustedHosts.Replace("wsman/","") -Role Client -Force | Out-Null
            }
            catch{}
        }
        if($ClientRemotingStatus.PreviousTrustedHosts -ne $null){
            Write-BoxstarterMessage "Reseting wsman Trusted Hosts to $($ClientRemotingStatus.PreviousTrustedHosts)"
            Set-Item "wsman:\localhost\client\trustedhosts" -Value "$($ClientRemotingStatus.PreviousTrustedHosts)" -Force
        }
        Write-BoxstarterMessage "Reseting GroupPolicy for Credentials Delegation"
        (Get-Item "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property | % {
            if([int]$_ -gt $ClientRemotingStatus["PreviousFreshNTLMCredDelegationHostCount"]) {
                Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name $_
            }
        }
        if(Test-Path "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials") {
            (Get-Item "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials").Property | % {
                if([int]$_ -gt $ClientRemotingStatus["PreviousFreshCredDelegationHostCount"]) {
                    Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials" -Name $_
                }
            }
        }
    }
}