function Get-PackageRoot{
<#
.SYNOPSIS
Returns the Root path of a Boxstarter Package given the Chocolatey $MyInvocation

.DESCRIPTION
This function is intended to be called from inside a running
ChocolateyInstall.ps1 file. It returns the root path of the package
which is one level above the Tools directory. This can be helpful
when you need to reference any files that you copied to your 
Boxstarter Repository which copies them to this location usung
New-BoxstarterPackage.

.PARAMETER Invocation
This is $MyInvocation instance accesible from ChocolateyInstall.ps1

.EXAMPLE
Copy-Item "$env:programfiles\Sublime Text 2\Data\*" Package\Sublime -recurse
New_BoxstarterPackage MyPackage .\Package
#Edit install script
Notepad $($Boxstarter.LocalRepo)\MyPackage\Tools\chocolateyInstall.ps1
Invoke-BoxstarterBuild MyPackage
Invoke-ChocolateyBoxstarter MyPackage

--ChocolateyInstall.ps1--
try {
    cinst sublimetext2
    $sublimeDir = "$env:programfiles\Sublime Text 2"
    mkdir "$sublimeDir\data"
    copy-item (Join-Path Get-PackageRoot($MyInvocation) 'sublime\*') "$sublimeDir\data" -Force -Recurse
    Write-ChocolateySuccess 'MyPackage'
} catch {
  Write-ChocolateyFailure 'MyPackage' $($_.Exception.Message)
  throw
}

.NOTES
Get-PackageRoot is intended to be called from ChocolateyInstall.ps1 
and will throw if it is called from another file.

.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
New_BoxstarterPackage
Invoke-ChocolateyBoxstarter
Invoke-BoxstarterBuild
#>
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.InvocationInfo]$invocation
    )
    if($invocation.MyCommand.Definition -eq $null -or !($invocation.MyCommand.Definition.ToLower().EndsWith("tools\chocolateyinstall.ps1"))){
        throw "Get-PackageRoot can only be used inside of chocolateyinstall.ps1. You Tried to call it from $($invocation.MyCommand.Definition)"
    }
    return (Split-Path -parent(Split-Path -parent $invocation.MyCommand.Definition))
}