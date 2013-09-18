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
<#
    If(remote not trusted){
        add computer to trusted hosts
    }

    setup credssp

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