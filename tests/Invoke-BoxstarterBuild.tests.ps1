$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}
Resolve-Path $here\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }

Describe "Invoke-BoxstarterBuild" {
    $Boxstarter.BaseDir=(Get-PSDrive TestDrive).Root
    $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    $Boxstarter.SuppressLogging=$true
    $packageName="pkg"
    Context "When Building a single package" {
        Mock Check-Chocolatey
        New-BoxstarterPackage $packageName

        Invoke-BoxstarterBuild $packageName

        It "Will Create the nupkg" {
            Join-Path $Boxstarter.LocalRepo "$packageName.1.0.0.nupkg" | Should Exist
        }
    }

    Context "When Building all packages" {
        Mock Check-Chocolatey
        New-BoxstarterPackage "pkg1"
        New-BoxstarterPackage "pkg2"

        Invoke-BoxstarterBuild -all

        It "Will Create nupkg files for all packages" {
            Join-Path $Boxstarter.LocalRepo "pkg1.1.0.0.nupkg" | Should Exist
            Join-Path $Boxstarter.LocalRepo "pkg2.1.0.0.nupkg" | Should Exist
        }
    }


    Context "When LocalRepo is null" {
        Mock Check-Chocolatey
        New-BoxstarterPackage $packageName
        $boxstarter.LocalRepo = $null

        try {Invoke-BoxstarterBuild $packageName} catch { $exception=$_ }

        It "Will throw LocalRepo is null" {
            $exception | Should match "No Local Repository has been set*"
        }
        $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    }

    Context "When No nuspec is in the named repo" {
        Mock Check-Chocolatey
        Mkdir $Boxstarter.LocalRepo | Out-Null

        try {Invoke-BoxstarterBuild $packageName} catch { $exception=$_ }

        It "Will throw No Nuspec" {
            $exception | Should be "Cannot find nuspec for $packageName"
        }
    }

    Context "When No nuspec is in a directory when building all" {
        Mock Check-Chocolatey
        Mkdir (Join-Path $Boxstarter.LocalRepo "pkg1") | Out-Null
        Mkdir (Join-Path $Boxstarter.LocalRepo "pkg2") | Out-Null

        try {Invoke-BoxstarterBuild -all} catch { $exception=$_ }

        It "Will throw No Nuspec" {
            $exception | Should be "Cannot find nuspec for pkg1"
        }
    }
}