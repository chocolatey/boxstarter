function Set-BoxstarterShare {
<#
.SYNOPSIS
Shares the Boxstarter root directory - $Boxstarter.BaseDir

.DESCRIPTION
Shares the Boxstarter root directory - $Boxstarter.BaseDir - so that
it can be accessed remotely. This allows remote machines to Invoke
ChocolateyBoxstarter via \\server\shareName\Boxstarter.bat. Unless
specified otherwise, the share name is Boxstarter and Everyone is
given Read permissions.

.PARAMETER ShareName
The name to give to the share. This is the name by which other
machines can access it. Boxstarter is the default.

.PARAMETER Accounts
A list of accounts to be given read access to the share. Everyone is
the default.

.EXAMPLE
Set-BoxstarterShare

Shares the Boxstarter root as Boxstarter to everyone.

.EXAMPLE
Set-BoxstarterShare BuildRepo

Shares the Boxstarter Root as BuildRepo to everyone.

.EXAMPLE
Set-BoxstarterShare -Accounts "corp\mwrock","corp\gmichaels"

Shares the Boxstarter root as Boxstarter to mwrock and gmichaels in the corp domain.

.LINK
https://boxstarter.org
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
        Throw "Sharing $shareName on $($Boxstarter.BaseDir) to $acctOption was not successful. Use NET SHARE $ShareName to see if share already exists. To Delete the share use NET SHARE $ShareName /DELETE."
    }
}

