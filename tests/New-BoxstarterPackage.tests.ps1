$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}
Resolve-Path $here\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }

Describe "New-BoxstarterPackage" {
    $Boxstarter.BaseDir=(Get-PSDrive TestDrive).Root
    $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    $Boxstarter.SuppressLogging=$true
    $packageName="pkg"
    $Description="My Description"
    Context "When No Path is provided" {

        New-BoxstarterPackage $packageName $Description

        It "Will Create the nuspec" {
            join-path (Join-Path $Boxstarter.LocalRepo $packageName) "$packageName.nuspec" | Should Exist
        }
        It "Will Remove UnNeeded Metadata" {
            $nuspec= join-path (Join-Path $Boxstarter.LocalRepo $packageName) "$packageName.nuspec"
            [xml]$xml = Get-Content $nuspec
            $nodesToDelete = @("licenseUrl","projectUrl","iconUrl","requireLicenseAcceptance","releaseNotes", "copyright","dependencies")
            $xml.Package.Metadata.ChildNodes | ? { $nodesToDelete -contains $_.Name} | Should be $null
        }
        It "Will Set Description" {
            $nuspec= join-path (Join-Path $Boxstarter.LocalRepo $packageName) "$packageName.nuspec"
            [xml]$xml = Get-Content $nuspec
            $xml.Package.Metadata.Description | Should be $Description
        }
        It "Will Add Boxstarter tag" {
            $nuspec= join-path (Join-Path $Boxstarter.LocalRepo $packageName) "$packageName.nuspec"
            [xml]$xml = Get-Content $nuspec
            $xml.Package.Metadata.tags | Should be "Boxstarter"
        }
        It "Will Create ChocolateyInstall file" {
            join-path (Join-Path $Boxstarter.LocalRepo "$packageName\tools") "ChocolateyInstall.ps1" | Should Exist
        }        
    }
}