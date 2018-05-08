function Install-BoxstarterScripts {
<#
.SYNOPSIS
Installs scripts in a Chocolatey package repository that can be used to
integrate with Build servers and can bootstrap Boxstarter dependencies
and test chocolatey package installs upon a commit to the repository.

.DESCRIPTION
Install-BoxstarterScripts adds a directory to a Chocolatey package
repository named BoxstarterScripts. Scripts are then copied to this
directory that can be triggered by a build process. the scripts include a
MSBuild .proj file, a bootstrapper script that will download and install
all necessary Boxstarter Modules and dependencies if needed, and a build
script that performs the package tests and can publish successfully tested
packages.

.PARAMETER RepoRootPath
The path that points to the root of the Chocolatey package repository.

.Example
Install-BoxstarterScripts c:\chocolatey-Packages

Creates a BoxstarterScripts folder at c:\Chocolatey-Packages\BoxstarterScripts
that contains the scripts needed for a build server to call and invoke the
testing and publishing of Chocolatey packages.

.LINK
https://boxstarter.org
#>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$RepoRootPath
    )

    $scriptPath = Join-Path $RepoRootPath BoxstarterScripts
    Write-BoxstarterMessage "Copying Boxstarter TestRunner scripts to $scriptPath"

    if(!(Test-Path $scriptPath)) { Mkdir $scriptPath | Out-Null }
    Copy-Item "$($Boxstarter.BaseDir)\Boxstarter.TestRunner\bootstrap.ps1" $scriptPath -Force
    Copy-Item "$($Boxstarter.BaseDir)\Boxstarter.TestRunner\BoxstarterBuild.ps1" $scriptPath -Force
    Copy-Item "$($Boxstarter.BaseDir)\Boxstarter.TestRunner\boxstarter.proj" $scriptPath -Force
    Set-Content "$scriptPath\.gitignore" -Value "*-options.xml`r`nFeedAPIKeys.xml" -Force
}
