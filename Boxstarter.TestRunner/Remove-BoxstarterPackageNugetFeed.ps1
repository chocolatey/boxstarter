function Remove-BoxstarterPackageNugetFeed {
<#
.SYNOPSIS
Removes the NuGet feed associated with an individual package.

.DESCRIPTION
A Chocolatey package repository may publish different packages to
different feeds. Remove-BoxstarterPackageNugetFeed removes the NuGet
feed associated with a specified package name. After doing so, the
package will be associated with the DefaultNugetFeed that can be set
with Set-BoxstarterDeployOptions and is set to the public Chocolatey
feed by default. If you do not want any feed to be associated with a
package, explicitly use Set-BoxstarterPackageNugetFeed to set the
feed of a package to $null.

.PARAMETER PackageName
The name of a Chocolatey package in the local repository for which the
feed should be removed.

.Example
Remove-BoxstarterPackageNugetFeed MyPackageName

Removes the NuGet feed associated with MyPackageName

.LINK
https://boxstarter.org
Set-BoxstarterPackageNugetFeed
Get-BoxstarterPackageNugetFeed
Set-BoxstarterDeployOptions
Get-BoxstarterDeployOptions
#>
    [CmdletBinding()]
    param (
        [string]$packageName
    )
    $path=Get-PackageFeedsPath
    if(!(Test-Path $path)) {
        $feeds =  @{}
    }
    else {
        $feeds = Import-CliXML $path
    }

    $feeds.Remove($packageName)
    $feeds | Export-CliXML ($path)
}
