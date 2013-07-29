function Set-BoxstarterShare {
<#
.SYNOPSIS
Shares the Boxstarter rot directory - $Boxstarter.BaseDir

.DESCRIPTION
Shares the Boxstarter rot directory - $Boxstarter.BaseDir - so that 
it can be accessed remotely. This allows remote machines to Invoke 
ChocolateyBoxstarter via \\server\shareName\Boxstarter.bat. Unless 
specified otherwise, the share name is Boxstarter and Everyone is 
given Read permisions.

.PARAMETER ShareName
The name to give to the share. This is the name by which other 
machines can access it. Boxstarter is he default.

.PARAMETER Accounts
A ist of accounts to be given read access to the share. Everyone is 
the default.

.EXAMPLE
Set-BoxstarterShare

Shares the Boxstarter root as Boxstarter to everyone.

.EXAMPLE
Set-BoxstarterShare BuildRepo

Shares the Boxstrarter Root as BuildRepo to everyone.

.EXAMPLE
Set-BoxstarterShare -Accounts "corp\mwrock","corp\gmichaels"

Shares the Boxstarter root as Boxstarter to mwrock and gmichaels in the corp domain.

.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
Invoke-ChocolateyBoxstarter
New-BoxstarterPackage
Invoke-BoxstarterBuild
#>
    param(
        [string]$shareName="Boxstarter",
        [string[]]$accounts=@("Everyone")
    )
    if(!(Test-Admin)) {
        $unNormalized=(Get-Item "$($Boxstarter.Basedir)\Boxstarter.Chocolatey\BoxStarter.Chocolatey.psd1")
        $command = "-ExecutionPolicy bypass -command Import-Module `"$($unNormalized.FullName)`";Set-BoxstarterShare @PSBoundParameters"
        Start-Process powershell -verb runas -argumentlist $command
        return
    }

    foreach($account in $accounts){
        $acctOption += "/GRANT:'$account,READ' "
    }
    IEX "net share $shareName='$($Boxstarter.BaseDir)' $acctOption"
    if($LastExitCode -ne 0) {
        Throw "Share was not succesfull. Use NET SHARE $ShareName to see if share already exists. To Delete the share use NET SHARE $ShareName /DELETE."
    }
}

