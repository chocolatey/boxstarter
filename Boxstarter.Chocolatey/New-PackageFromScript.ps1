function New-PackageFromScript {
<#
.SYNOPSIS
Creates a Nuget package from a Chocolatey script

.DESCRIPTION
This creates a .nupkg file from a script file. It adds a dummy nuspec 
and packs the nuspec and script to a nuget package saved to 
$Boxstarter.LocalRepo. The function returns a string that is the 
Package Name of the package.

 .PARAMETER Source
 Either a file path or URI pointing to a resource containing a script.

.EXAMPLE
$packageName = New-PackageFromScript myScript.ps1

Creates a Package from the myScript.ps1 file in the current directory.

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
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
#>        
    [CmdletBinding()]
	param (
        [Parameter(Mandatory=1)]
        [string] $Source
    )

    Check-Chocolatey
    . "$env:ChocolateyInstall\chocolateyinstall\helpers\functions\Get-WebFile.ps1"
    if($source -like "*://*"){
        try {$text = Get-WebFile -url $Source -passthru } catch{
            throw "Unable to retrieve script from $source `r`nInner Exception is:`r`n$_"
        }
    }
    else {
        if(!(Test-Path $source)){
            throw "Path $source does not exist."
        }
        $text=Get-Content $source
    }

    $thisPackageName="temp_$env:Computername"
    if(Test-Path "$($boxstarter.LocalRepo)\$thisPackageName"){
        Remove-Item "$($boxstarter.LocalRepo)\$thisPackageName" -recurse -force
    }
    New-BoxstarterPackage $thisPackageName -quiet
    Set-Content "$($boxstarter.LocalRepo)\$thisPackageName\tools\ChocolateyInstall.ps1" -value $text
    Invoke-BoxstarterBuild $thisPackageName -quiet

    Write-BoxstarterMessage "Created a temporary package $thisPackageName from $source in $($boxstarter.LocalRepo)"
    return $thisPackageName
}