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
        Mock Check-Chocolatey

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

    Context "When a Path is provided that has no nuspec or chocolateyInstall" {
        Mock Check-Chocolatey
        mkdir (Join-Path $boxstarter.BaseDir "mypkg\dir1") |out-null
        New-Item (Join-Path $boxstarter.BaseDir "mypkg\test.txt") -type file | out-null
        New-Item (Join-Path $boxstarter.BaseDir "mypkg\dir1\test1.txt") -type file | out-null

        New-BoxstarterPackage $packageName $Description (Join-Path $boxstarter.BaseDir "mypkg")

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
        It "Will Copy existing items" {
            join-path (Join-Path $Boxstarter.LocalRepo $packageName) "test.txt" | Should Exist
            join-path (Join-Path $Boxstarter.LocalRepo "$packageName\dir1") "test1.txt" | Should Exist
        }        
    }    

    Context "When a Path is provided that has a nuspec" {
        Mock Check-Chocolatey
        mkdir (Join-Path $boxstarter.BaseDir "mypkg\dir1") |out-null
        New-Item (Join-Path $boxstarter.BaseDir "mypkg\pkg.nuspec") -type file -value "my nuspec" | out-null

        New-BoxstarterPackage $packageName $Description (Join-Path $boxstarter.BaseDir "mypkg")

        It "Will not Create the nuspec" {
            get-content (join-path (Join-Path $Boxstarter.LocalRepo $packageName) "$packageName.nuspec") | Should be "my nuspec"
        }
    }

    Context "When a Path is provided that has a chocolateyInstall" {
        Mock Check-Chocolatey
        mkdir (Join-Path $boxstarter.BaseDir "mypkg\tools") |out-null
        New-Item (Join-Path $boxstarter.BaseDir "mypkg\tools\chocolateyInstall.ps1") -type file -value "my install" | out-null

        New-BoxstarterPackage $packageName $Description (Join-Path $boxstarter.BaseDir "mypkg")

        It "Will not Create the chocolateyInstall" {
            get-content (join-path (Join-Path $Boxstarter.LocalRepo $packageName) "tools\chocolateyInstall.ps1") | Should be "my install"
        }
    }    

    Context "When a LocalRepo is null" {
        Mock Check-Chocolatey
        $boxstarter.LocalRepo = $null

        try {New-BoxstarterPackage $packageName $Description} catch { $exception=$_ }

        It "Will throw LocalRepo is null" {
            $exception | Should match "No Local Repository has been set*"
        }
        $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    }

    Context "When a package name is not valid" {
        Mock Check-Chocolatey
        try {New-BoxstarterPackage "my: invalid name" $Description} catch [System.ArgumentException]{ $exception=$_ }

        It "Will throw ArgumentException" {
            $exception | Should not be $null
        }
    } 

    Context "When a package directory already exists" {
        Mock Check-Chocolatey
        mkdir (Join-Path $boxstarter.LocalRepo $packageName) |out-null

        try {New-BoxstarterPackage $packageName $Description} catch { $exception=$_ }

        It "Will throw Repo dir exists" {
            $exception | Should match "A local Repo already exists*"
        }
    }    

    Context "When a path is provided that does not exist" {
        Mock Check-Chocolatey

        try {New-BoxstarterPackage $packageName $Description (Join-Path $boxstarter.BaseDir "mypkg") } catch { $exception=$_ }

        It "Will throw path does not exist" {
            $exception.exception.Message.EndsWith("could not be found") | Should be $true
        }
    }    
}