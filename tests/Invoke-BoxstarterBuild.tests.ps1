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
        Mock Write-Host -parameterFilter {$ForegroundColor -eq $null}
        Mock Intercept-Chocolatey
        New-BoxstarterPackage $packageName | Out-Null

        Invoke-BoxstarterBuild $packageName | Out-Null

        It "Will Create the nupkg" {
            Join-Path $Boxstarter.LocalRepo "$packageName.1.0.0.nupkg" | Should Exist
        }
        It "Should not intercept chocolatey" {
            Assert-MockCalled Intercept-Chocolatey -Times 0
        }

    }

    Context "When Building all packages" {
        Mock Write-Host -parameterFilter {$ForegroundColor -eq $null}
        Mock Check-Chocolatey
        New-BoxstarterPackage "pkg1" | Out-Null
        New-BoxstarterPackage "pkg2" | Out-Null

        Invoke-BoxstarterBuild -all | Out-Null

        It "Will Create nupkg files for all packages" {
            Join-Path $Boxstarter.LocalRepo "pkg1.1.0.0.nupkg" | Should Exist
            Join-Path $Boxstarter.LocalRepo "pkg2.1.0.0.nupkg" | Should Exist
        }
    }


    Context "When LocalRepo is null" {
        Mock Write-Host -parameterFilter {$ForegroundColor -eq $null}        
        Mock Check-Chocolatey
        New-BoxstarterPackage $packageName | Out-Null
        $boxstarter.LocalRepo = $null

        try {Invoke-BoxstarterBuild $packageName} catch { $ex=$_ }

        It "Will throw LocalRepo is null" {
            $ex | Should match "No Local Repository has been set*"
        }
        $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    }

    Context "When No nuspec is in the named repo" {
        Mock Write-Host -parameterFilter {$ForegroundColor -eq $null}
        Mock Check-Chocolatey
        Mkdir $Boxstarter.LocalRepo | Out-Null

        try {Invoke-BoxstarterBuild $packageName} catch { $ex=$_ }

        It "Will throw No Nuspec" {
            $ex | Should be "Cannot find $packageName\$packageName.nuspec"
        }
    }

    Context "When No nuspec is in a directory when building all" {
        Mock Write-Host -parameterFilter {$ForegroundColor -eq $null}
        Mock Check-Chocolatey
        Mkdir (Join-Path $Boxstarter.LocalRepo "pkg1") | Out-Null
        Mkdir (Join-Path $Boxstarter.LocalRepo "pkg2") | Out-Null

        try {Invoke-BoxstarterBuild -all} catch { $ex=$_ }

        It "Will throw No Nuspec" {
            $ex | Should be "Cannot find nuspec for pkg1"
        }
        [GC]::Collect() #pester test drive kept bombing on cleanup without this
    }
}