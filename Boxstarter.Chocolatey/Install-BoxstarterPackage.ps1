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
        [PSCredential]$Credential,
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
        if($Session -ne $null){
            $siid = $session.InstanceId
        }
        else{
            $ClientRemotingStatus=Enable-BoxstarterClientRemoting $ComputerName
            if(!$ClientRemotingStatus.Success){return}

            if(!(Enable-RemotingOnRemote $ComputerName $Credential)){return}

            $session = New-PSSession $ComputerName -Credential $Credential -Authentication credssp -SessionOption @{ApplicationArguments=@{RemoteBoxstarter="MyValue"}}
        }

        Setup-BoxstarterModuleAndLocalRepo $session
        
        Invoke-Remotely $session $Credential $PackageName $DisableReboots $NoPassword
    }
    finally{
        if($session -ne $null -and $session.InstanceId -ne $siid) {Remove-PSSession $Session}
        if($ClientRemotingStatus -ne $null -and $ClientRemotingStatus.Success){
            Disable-WSManCredSSP -Role Client
            if($ClientRemotingStatus.PreviousCSSPTrustedHosts -ne $null){
                try{
                    Write-BoxstarterMessage "Reseting CredSSP Trusted Hosts to $($ClientRemotingStatus.PreviousCSSPTrustedHosts.Replace('wsman/',''))"
                    Enable-WSManCredSSP -DelegateComputer $ClientRemotingStatus.PreviousCSSPTrustedHosts.Replace("wsman/","") -Role Client -Force
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
}

function Invoke-Locally {
    param(
        [string]$PackageName,
        [PSCredential]$Credential,
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
    $remotingTest = Invoke-Command $ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction SilentlyContinue
    if($remotingTest -eq $null){
        Write-BoxstarterMessage "Powershell Remoting is not enabled or accesible on $ComputerName"
        $wmiTest=Invoke-WmiMethod -Computer $ComputerName -Credential $Credential Win32_Process Create -Args "cmd.exe" -ErrorAction SilentlyContinue
        if($wmiTest -eq $null){
            Throw @"
Unable at access remote computer via Powershell Remoting or WMI. 
You can enable it by running:
 Enable-PSRemoting -Force 
from an Administrator Powershell console on the remote computer.
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

function Invoke-Remotely($session,$Credential,$Package,$DisableReboots,$NoPassword){
    while($session.Availability -eq "Available") {
        $remoteResult = Invoke-Command $session {
            param($possibleResult,$SuppressLogging,$pkg,$password,$DisableReboots,$NoPassword)
            Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
            $Boxstarter.SuppressLogging=$SuppressLogging
            $result=$null
            try {
                $result = Invoke-ChocolateyBoxstarter $pkg -Password $password -SuppressRebootScript -NoPassword:$NoPassword -DisableReboots:$DisableReboots
            }
            catch{
                throw
            }
            return $result
        } -ArgumentList $possibleResult, $Boxstarter.SuppressLogging, $Package, $Credential.Password, $DisableReboots, $NoPassword

        write-host "result $($remoteResult.Result)"
        if($remoteResult -eq $null -or $remoteResult.Result -eq "Rebooting") {
            if($remoteResult -ne $null -and  $remoteResult.Result -eq "Rebooting"){
                Write-BoxstarterMessage "Waiting for $($session.ComputerName) to sever remote session..."
                while($session.State -eq "Opened"){
                    start-sleep -seconds 2
                }
            }
            $reconnected=$false
            Write-BoxstarterMessage "Waiting for $($session.ComputerName) to respond to remoting..."
            Remove-PSSession $session
            Do{
                $response=$null
                start-sleep -seconds 2
                $session = New-PSSession $ComputerName -Credential $Credential -Authentication credssp -SessionOption @{ApplicationArguments=@{RemoteBoxstarter="MyValue"}} -ErrorAction SilentlyContinue
                if($session -ne $null -and $Session.Availability -eq "Available"){
                    $response=Invoke-Command $session.ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $credential -ErrorAction SilentlyContinue
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