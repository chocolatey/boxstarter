function Set-BoxstarterPackageNugetFeed {
<#
.SYNOPSIS
Sets the Nuget feed associated with an individual package.

.DESCRIPTION
A Chocolatey package repository may publish different packages to 
different feeds. Set-BoxstarterPackageNugetFeed sets the Nuget 
feed associated with a specified package name. 
Get-BoxstarterPackageNugetFeed can be used to retrieve the feed 
associated with a package. One may also use Set-BoxstarterDeployOptions 
and use the DefaultNugetFeed parameter to specify which feed to use for 
a package if no feed is specified. If you do not want any feed to be 
associated with a package, explicitly use Set-BoxstarterPackageNugetFeed 
to set the feed of a package to $null.

.PARAMETER PackageName
The name of a Chocolatey package in the local repository for which a 
feed should be associated.

.PARAMETER NugetFeed
The Nuget feed to associate with the Chocolatey package.

.NOTES
These feed associations are persisted to a file so thet they can be 
reused in all subsequent sessions.

.Example
set-BoxstarterPackageNugetFeed -PackageName MyPackage `
  -NugetFeed https://www.myget.org/F/mywackyfeed/api/v2

Sets the package MyPackage to the MyGet.org mywackyfeed 

.LINK
http://boxstarter.codeplex.com
Get-BoxstarterPackageNugetFeed
Remove-BoxstarterPackageNugetFeed
Set-BoxstarterDeployOptions
Get-BoxstarterDeployOptions
#>
    [CmdletBinding()]
    param (
        [string]$PackageName,
        [Uri]$NugetFeed
    )
    if(!(Test-Path "$($Boxstarter.LocalRepo)\$PackageName")) {
        throw New-Object -TypeName InvalidOperationException -ArgumentList "The $PackageName package could not be found. There is no directory $($Boxstarter.LocalRepo)\$PackageName"
    }

    $path=Get-PackageFeedsPath
    if(!(Test-Path $path)) { 
        $feeds =  @{}
    }
    else {
        $feeds = Import-CliXML $path
    }

    $feeds.$PackageName = $NugetFeed
    $feeds | Export-CliXML ($path)
}