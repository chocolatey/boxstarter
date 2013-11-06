function Install-BoxstarterPackage {
    [CmdletBinding()]
	param(
        [parameter(Mandatory=$true, Position=0, ParameterSetName="ComputerName")]
        [string]$ComputerName,
        [parameter(Mandatory=$true, Position=0, ParameterSetName="Uri")]
        [Uri]$ConnectionUri,
        [parameter(Mandatory=$true, Position=0, ParameterSetName="Session")]
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [parameter(Mandatory=$true, Position=0, ParameterSetName="Package")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="ComputerName")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="Uri")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="Session")]
        [string]$PackageName,
        [Management.Automation.PsCredential]$Credential,
        [switch]$Force,
        [switch]$DisableReboots,
        [switch]$KeepWindowOpen,
        [switch]$NoPassword      
    )

    if($PsCmdlet.ParameterSetName -eq "Package"){
        Invoke-Locally @PSBoundParameters
        return
    }

    try{
        $sessionArgs=@{}
        if($Credential){
            $sessionArgs.Credential=$Credential
        }
        if($Session -ne $null){
            if($session.Availability -ne "Available"){
                throw New-Object -TypeName ArgumentException -ArgumentList "The Session is not Available"
            }
            $siid = $session.InstanceId
            Set-SessionArgs $Session $sessionArgs
        }
        else{
            if($ConnectionURI){
                $sessionArgs.ConnectionURI = $ConnectionURI
                $computerName=$ConnectionURI.Host
            }
            else {
                $sessionArgs.ComputerName = $ComputerName
            }
            $ClientRemotingStatus=Enable-BoxstarterClientRemoting $ComputerName
            if(!$ClientRemotingStatus.Success){return}

            if(!(Enable-RemotingOnRemote $ComputerName $Credential)){return}

            $enableCredSSP = Should-EnableCredSSP $Credential $sessionArgs $computerName

            $session = New-PSSession @sessionArgs
        }

        Setup-BoxstarterModuleAndLocalRepo $session

        if($enableCredSSP){
            if($session){Remove-PSSession $session}
            $session = Enable-RemoteCredSSP $Credential $sessionArgs
        }
        
        Invoke-Remotely $session $Credential $PackageName $DisableReboots $NoPassword $sessionArgs
    }
    finally{
        if($enableCredSSP){
            Disable-RemoteCredSSP $sessionArgs $Credential
        }
        if($session -ne $null -and $session.InstanceId -ne $siid) {
            Remove-PSSession $Session
            $Session = $null
        }
        Rollback-ClientRemoting $ClientRemotingStatus
    }
}

function Invoke-Locally {
    param(
        [string]$PackageName,
        [Management.Automation.PsCredential]$Credential,
        [switch]$Force,
        [switch]$DisableReboots,
        [switch]$KeepWindowOpen,
        [switch]$NoPassword      
    )
    if($PSBoundParameters.ContainsKey("Credential")){
        if(!($PSBoundParameters.ContainsKey("NoPassword"))){
            $PSBoundParameters.Add("Password",$PSBoundParameters["Credential"].Password)
        }
        $PSBoundParameters.Remove("Credential") | out-Null
    }
    if($PSBoundParameters.ContainsKey("Force")){
        $PSBoundParameters.Remove("Force") | out-Null
    }
    $PSBoundParameters.Add("BootstrapPackage", $PSBoundParameters.PackageName)
    $PSBoundParameters.Remove("PackageName") | out-Null

    Invoke-ChocolateyBoxstarter @PSBoundParameters
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
            Throw @"
Unable at access remote computer via Powershell Remoting or WMI. 
You can enable it by running:
 Enable-PSRemoting -Force 
from an Administrator Powershell console on the remote computer.
Original Exception: $ex
"@
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
    Write-BoxstarterMessage "Copying Boxstarter Modules to $env:temp on $($Session.ComputerName)"
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

function Invoke-Remotely($session,$Credential,$Package,$DisableReboots,$NoPassword,$sessionArgs){
    while($session.Availability -eq "Available") {
        $remoteResult = Invoke-Command $session {
            param($possibleResult,$SuppressLogging,$pkg,$password,$DisableReboots,$NoPassword)
            Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
            $Boxstarter.SuppressLogging=$SuppressLogging
            $result=$null
            try {
                $result = Invoke-ChocolateyBoxstarter $pkg -Password $password -NoPassword:$NoPassword -DisableReboots:$DisableReboots
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
        } -ArgumentList $possibleResult, $Boxstarter.SuppressLogging, $Package, $Credential.Password, $DisableReboots, $NoPassword
        
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
                $session = New-PSSession @sessionArgs -ErrorAction SilentlyContinue
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
    $uri = Invoke-Command $session {return $PSSenderInfo.ConnectionString}
    if($uri){
        $sessionArgs.ConnectionURI=$uri
    }
    else{
        $sessionArgs.ComputerName=$session.ComputerName
    }    
}

function Should-EnableCredSSP($Credential, $sessionArgs, $computerName) {
    if($Credential){
        try {$credsspEnabled = Test-WsMan @sessionArgs -Authentication CredSSP -ErrorAction SilentlyContinue } catch {}
        if($credsspEnabled -eq $null){
            return $True
        }
        else{
            $credsspEnabled = Test-WsMan -ComputerName $ComputerName -Credential $Credential -Authentication CredSSP -ErrorAction SilentlyContinue
            if($credsspEnabled -ne $null){ $sessionArgs.Authentication="CredSSP" }
        }
    }
    return $false
}

function Enable-RemoteCredSSP($Credential, $sessionArgs) {
    Write-BoxstarterMessage "Enabling CredSSP Authentication on $ComputerName"
    Invoke-Command @sessionArgs { 
        param($Credential)
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        Invoke-FromTask "Enable-WSManCredSSP -Role Server -Force | out-Null" 
    } -ArgumentList $Credential
    $sessionArgs.Authentication="CredSSP"
    return New-PSSession @sessionArgs
}

function Disable-RemoteCredSSP ($sessionArgs, $Credential){
    Write-BoxstarterMessage "Disabling CredSSP Authentication on $ComputerName"
    Invoke-Command @sessionArgs { 
        param($Credential)
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        Invoke-FromTask "Disable-WSManCredSSP -Role Server | Out-Null"
        Remove-BoxstarterTask
    } -ArgumentList $Credential
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
            if([int]$_ -gt $ClientRemotingStatus["PreviousFreshCredDelegationHostCount"]) {
                Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name $_
            }
        }
    }
}