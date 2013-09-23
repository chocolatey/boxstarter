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

    $ClientRemotingStatus=Enable-RemotingOnClient $ComputerName
    if(!$ClientRemotingStatus.Success){return}

    try{
        if(!(Enable-RemotingOnRemote $ComputerName $Credential)){return}

        if($session -eq $null){
            $session = New-PSSession $ComputerName -Credential $Credential
        }

        Setup-BoxstarterModuleAndLocalRepo $session
        
        Invoke-Remotely $session $Credential
    }
    finally{
        if($ClientRemotingStatus.Success){
            Disable-WSManCredSSP -Role Client
            if($ClientRemotingStatus.PreviousCSSPTrustedHosts -ne $null){
                Enable-WSManCredSSP -DelegateComputer $ClientRemotingStatus.PreviousCSSPTrustedHosts.Replace("wsman/","") -Role Client -Force
            }
            if($ClientRemotingStatus.PreviousTrustedHosts -ne $null){
                Set-Item "wsman:\localhost\client\trustedhosts" -Value $ClientRemotingStatus.PreviousTrustedHosts -Force
            }
        }
    }
}

function Confirm-Choice ($message, $caption = $message) {
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    switch ($answer){
        0 {return $true; break}
        1 {return $false; break}
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

function Enable-RemotingOnClient($RemoteHostToTrust){
    $Result=@{
        Success=$False;
        PreviousTrustedHosts=$null;
        PreviousCSSPTrustedHosts=$null
    }

    try { $credssp = Get-WSManCredSSP } catch { $credssp = $_}
    if($credssp.Exception -ne $null){
        if($Force -or (Confirm-Choice "Powershell remoting is not enabled locally. Should Boxstarter enable powershell remoting?"))
        {
            Enable-PSRemoting -Force
        }else {
            return $Result
        }
    }

    if($credssp -is [Object[]]){
        $idxHosts=$credssp[0].IndexOf(": ")
        if($idxHosts -gt -1){
            $credsspEnabled=$True
            $Result.PreviousCSSPTrustedHosts=$credssp[0].substring($idxHosts+2)
            $hostArray=$Result.PreviousCSSPTrustedHosts.Split(",")
            if($hostArray -contains "wsman/$RemoteHostToTrust"){
                $ComputerAdded=$True
            }
        }
    }

    if($ComputerAdded -eq $null){
        Enable-WSManCredSSP -DelegateComputer $RemoteHostToTrust -Role Client -Force
    }

    $Result.PreviousTrustedHosts=(Get-Item "wsman:\localhost\client\trustedhosts").Value
    $hostArray=$Result.PreviousTrustedHosts.Split(",")
    if($hostArray.length -eq 1 -and $hostArray[0].length -eq 0) {
        $newHosts=$RemoteHostToTrust
    }
    elseif(!($hostArray -contains $RemoteHostToTrust)){
        $newHosts=$Result.PreviousTrustedHosts + "," + $RemoteHostToTrust
    }
    if($newHosts -ne $null) {
        Set-Item "wsman:\localhost\client\trustedhosts" -Value $newHosts -Force
    }

    $Result.Success=$True
    return $Result
}

function Enable-RemotingOnRemote ($ComputerName, $Credential){
    $remotingTest = Invoke-Command $ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction SilentlyContinue
    if($remotingTest -eq $null){
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
            Enable-RemotePSRemoting $ComputerName $Credential
        }
        else {
            return $False
        }
    }
    return $True
}

function Setup-BoxstarterModuleAndLocalRepo($session){
    Send-File "$basedir\Boxstarter.Chocolatey\bootstrapper.ps1" boxstarter\bootstrapper.ps1 $session
    Get-ChildItem $Boxstarter.LocalRepo\*.nupkg | % { Send-File $_.ProviderPath Boxstarter\$_.Name $session }
    Invoke-Command -Session $Session {
        . $env:temp\boxstarter\bootstrapper.ps1
        Get-Boxstarter -Force
        Import-Module $env:Appdata\Boxstarter\Boxstarter.Chocolatey.psd1
        $Boxstarter.LocalRepo="$env:temp\boxstarter"
    }
}

function Invoke-Remotely($session,$Credential){
    while($session.State -eq "Opened") {
        if($postReboot -ne $null){
            $response=$null
            Do{
                $response=Invoke-Command $session.ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $credential -ErrorAction SilentlyContinue
            }
            Until($response -ne $null)
            $session = New-PSSession $ComputerName -Credential $Credential
        }
        $postReboot=Invoke-Command $session {
            param($pkg,$password)
            Invoke-ChocolateyBoxstarter $pkg -Password $password -ReturnRebootScript
        } -Argumentist $Package, $Credential.GetNetworkCredential().Password
    }
}