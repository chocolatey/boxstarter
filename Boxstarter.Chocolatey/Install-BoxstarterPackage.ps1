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
        return
    }

    try { $credssp = Get-WSManCredSSP } catch { $credssp = $_}
    if($credssp.Exception -ne $null){
        if($Force -or (Confirm-Choice "Powershell remoting is not enabled locally. Should Boxstarter enable powershell remoting?"))
        {
            Enable-PSRemoting -Force
        }else {
            return
        }
    }

    if($credssp -is [Object[]]){
        $idxHosts=$credssp[0].IndexOf(": ")
        if($idxHosts -gt -1){
            $credsspEnabled=$True
            $currentHosts+=$credssp[0].substring($idxHosts+2)
            $hostArray=$currentHosts.Split(",")
            if($hostArray -contains "wsman/$ComputerName"){
                $ComputerAdded=$True
            }
        }
    }

    try{
        if($ComputerAdded -eq $null){
            Enable-WSManCredSSP -DelegateComputer $ComputerName -Role Client -Force
        }

        $currentTrustedHosts=Get-Item "wsman:\localhost\client\trustedhosts"
        $hostArray=$currentTrustedHosts.Value.Split(",")
        if($hostArray.length -eq 1 -and $hostArray[0].length -eq 0) {
            $newHosts=$ComputerName
        }
        elseif(!($hostArray -contains $ComputerName)){
            $newHosts=$currentTrustedHosts.Value + "," + $ComputerName
        }
        if($newHosts -ne $null) {
            Set-Item "wsman:\localhost\client\trustedhosts" -Value $newHosts -Force
        }

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
                return
            }
        }

        if($session -eq $null){
            $session = New-PSSession $ComputerName -Credential $Credential
        }
        Send-File "$basedir\Boxstarter.Chocolatey\bootstrapper.ps1" boxstarter\bootstrapper.ps1 $session
        Get-ChildItem $Boxstarter.LocalRepo\*.nupkg | % { Send-File $_.ProviderPath Boxstarter\$_.Name $session }
        Invoke-Command -Session $Session {
            . $env:temp\boxstarter\bootstrapper.ps1
            Get-Boxstarter -Force
            Import-Module $env:Appdata\Boxstarter\Boxstarter.Chocolatey.psd1
            $Boxstarter.LocalRepo=$env:temp\boxstarter
        }
        
        Do {
            if($postReboot -ne $null){
                Invoke-Command $session { Restart-Computer -Force}
                $response=$null
                Do{
                    $response=Invoke-Command $computername { Get-WmiObject Win32_ComputerSystem } -Credential $credential -ErrorAction SilentlyContinue
                }
                Until($response -ne $null)
                $session = New-PSSession $ComputerName -Credential $Credential
            }
            $postReboot=Invoke-Command $session {
                param($pkg,$password)
                Invoke-ChocolateyBoxstarter $pkg -Password $password -ReturnRebootScript
            } -Argumentist $Package, $Credential.GetNetworkCredential().Password
        }
        Until($postReboot -eq $null)
    }
    finally{
        Disable-WSManCredSSP -Role Client
        if($credsspEnabled){
            Enable-WSManCredSSP -DelegateComputer $currentHosts.Replace("wsman/","") -Role Client -Force
        }
        if($currentTrustedHosts -ne $null){
            Set-Item "wsman:\localhost\client\trustedhosts" -Value $currentTrustedHosts.Value -Force
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
