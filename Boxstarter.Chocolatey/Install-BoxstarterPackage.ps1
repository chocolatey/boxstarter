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

    <#
        If (remoting Not enabled) {
            if(wmi not enabled){
                throw
            }
            If(!Force){
                confirm ok to enable remoting
            }
            if(confirmed){
                enable remoting
            }
            if(!test-remoting){
                throw
            }
        }

        build zip of modules and package (if local)
        copy bytes
        invoke remote extraction

        Build script to invoke boxstarter

        Invoke script remotely

        If a new script was returned{
            restart remote computer
            wait for it to come back
            invoke the script
        }
    #>
    }
    finally{
        Disable-WSManCredSSP -Role Client
        if($credsspEnabled){
            Enable-WSManCredSSP -DelegateComputer $currentHosts.Replace("wsman/","") -Role Client -Force
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
