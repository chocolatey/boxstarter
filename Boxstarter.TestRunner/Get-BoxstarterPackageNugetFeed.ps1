function Get-BoxstarterPackageNugetFeed {
<#
.SYNOPSIS
Gets the Nuget feed associated with an individual package.

.DESCRIPTION
A Chocolatey package repository may publish different packages to 
different feeds. Get-BoxstarterPackageNugetFeed retrieves the Nuget 
feed associated with a specified package name. 
Set-BoxstarterPackageNugetFeed can be used to specify a feed to be 
associated with a package. One may also use Set-BoxstarterDeployOptions 
and use the DefaultNugetFeed parameter to specify which feed to use for 
a package if no feed is specified. If you do not want any feed to be 
associated with a package, explicitly use Set-BoxstarterPackageNugetFeed 
to set the feed of a package to $null.

.PARAMETER PackageName
The name of a Chocolatey package in the local repository for which a 
feed should be retrieved.

.Example
Get-BoxstarterPackageNugetFeed MyPackageName

Retrieves the Nuget feed associated with MyPackageName

.LINK
http://boxstarter.org
Set-BoxstarterPackageNugetFeed
Remove-BoxstarterPackageNugetFeed
Set-BoxstarterDeployOptions
Get-BoxstarterDeployOptions
#>
    [CmdletBinding()]
    param (
        [string]$PackageName
    )

    $path=Get-PackageFeedsPath
    if(!(Test-Path $path)) { 
        $feeds =  @{}
    }
    else {
        $feeds = Import-CliXML $path
    }

    if($feeds.ContainsKey($packageName)) {
        return $feeds.$packageName
    }
    else {
        return (Get-BoxstarterDeployOptions).DefaultNugetFeed
    }
}