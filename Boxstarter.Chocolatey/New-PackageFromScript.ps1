function New-PackageFromScript {
<#
.SYNOPSIS
Creates a NuGet package from a Chocolatey script

.DESCRIPTION
This creates a .nupkg file from a script file. It adds a dummy nuspec
and packs the nuspec and script to a NuGet package saved to
$Boxstarter.LocalRepo. The function returns a string that is the
Package Name of the package.

 .PARAMETER Source
 Either a file path or URI pointing to a resource containing a script.

 .PARAMETER PackageName
 The name of the package. If not provided, this will be "temp_BoxstarterPackage"

.EXAMPLE
$packageName = New-PackageFromScript myScript.ps1

Creates a Package from the myScript.ps1 file in the current directory.

.EXAMPLE
$packageName = New-PackageFromScript myScript.ps1 MyPackage

Creates a Package named "MyPackage" from the myScript.ps1 file in the current directory.

.EXAMPLE
$packageName = New-PackageFromScript c:\path\myScript.ps1

Creates a Package from the myScript.ps1 file in c:\path\myScript.ps1.

.EXAMPLE
$packageName = New-PackageFromScript \\server\share\myScript.ps1

Creates a Package from the myScript.ps1 file the share at \\server\share\myScript.ps1.

.EXAMPLE
$packageName = New-PackageFromScript https://gist.github.com/mwrock/6771863/raw/b579aa269c791a53ee1481ad01711b60090db1e2/gistfile1.txt

Creates a Package from the gist located at
https://gist.github.com/mwrock/6771863/raw/b579aa269c791a53ee1481ad01711b60090db1e2/gistfile1.txt

.LINK
https://boxstarter.org
about_boxstarter_chocolatey
#>
    [CmdletBinding()]
	param (
        [Parameter(Mandatory=1)]
        [string] $Source,
        [string] $PackageName="temp_BoxstarterPackage"
    )

    $chocoInstall = [System.Environment]::GetEnvironmentVariable('ChocolateyInstall', 'MACHINE')
    if($chocoInstall -eq $null) {
        # Simply Installs choco repo and helpers
        Call-Chocolatey -Command 'install' -PackageNames @('chocolatey')
        $chocoInstall = [System.Environment]::GetEnvironmentVariable('ChocolateyInstall', 'MACHINE')
    }
    if($source -like "*://*"){
        try {$text = Get-HttpResource -url $Source -passthru } catch{
            throw "Unable to retrieve script from $source `r`nInner Exception is:`r`n$_"
        }
    }
    else {
        if(!(Test-Path $source)){
            throw "Path $source does not exist."
        }
        $text=Get-Content $source
    }

    if(Test-Path "$($boxstarter.LocalRepo)\$PackageName"){
        Remove-Item "$($boxstarter.LocalRepo)\$PackageName" -recurse -force
    }
    New-BoxstarterPackage $PackageName -quiet | Out-Null
    Set-Content "$($boxstarter.LocalRepo)\$PackageName\tools\ChocolateyInstall.ps1" -value $text
    Invoke-BoxstarterBuild $PackageName -quiet

    Write-BoxstarterMessage "Created a temporary package $PackageName from $source in $($boxstarter.LocalRepo)"
    return $PackageName
}
