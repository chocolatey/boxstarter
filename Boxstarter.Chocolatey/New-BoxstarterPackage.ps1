function New-BoxstarterPackage {
<#
.SYNOPSIS
Creates a new Chocolatey package source directory intended for a Boxstarter Install

.DESCRIPTION
New-BoxstarterPackage creates a new Directory in your local 
Boxstarter repository located at $Boxstarter.LocalRepo. If no path is
provided, Boxstarter creates a minimal nuspec and 
ChocolateyInstall.ps1 file. If a path is provided, Boxstarter will 
copy the contents of the path to the new package directory. If the
path does not include a nuspec or ChocolateyInstall.ps1, Boxstarter
will create one. You can use Invoke-BoxstarterBuild to pack the 
repository directory to a Chocolatey nupkg.

.PARAMETER Name
The name of the package to create

.PARAMETER Path
Optional path whose contents will be copied to the repository

.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
Invoke-BoxstarterBuild
#>
    param(
        [string]$Name,
        [string]$path
    )
}