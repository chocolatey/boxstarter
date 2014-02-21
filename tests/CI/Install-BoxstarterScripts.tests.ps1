$here = Split-Path -Parent $MyInvocation.MyCommand.Path
get-module Boxstarter.* | Remove-Module -ErrorAction  SilentlyContinue
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 |
    ? { $_.Path -like "*-*" } | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.CI\*.ps1 | 
    ? { $_.Path -like "*-*" } | 
    % { . $_.ProviderPath }

Describe "Install-BoxstarterScripts" {
    $Boxstarter.BaseDir=(Get-PSDrive TestDrive).Root
    $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    $Boxstarter.SuppressLogging=$true
    Copy-Item $here\..\..\Boxstarter.CI $Boxstarter.BaseDir -Recurse 

    Context "When the repository exists" {
        Mkdir $Boxstarter.LocalRepo | Out-Null

        Install-BoxstarterScripts $Boxstarter.LocalRepo

        It "should copy bootstrapper" {
            join-Path $($Boxstarter.LocalRepo) "BoxstarterScripts\bootstrap.ps1" | Should exist
        }
        It "should copy msbuild file" {
            join-Path $($Boxstarter.LocalRepo) "BoxstarterScripts\boxstarter.proj" | Should exist
        }
        It "should copy BoxstarterBuild" {
            join-Path $($Boxstarter.LocalRepo) "BoxstarterScripts\BoxstarterBuild.ps1" | Should exist
        }
        It "should write ignore file for secrets" {
            Get-Content "$($Boxstarter.LocalRepo)\BoxstarterScripts\.gitignore" | Should be "*-options.xml"
        }
    }

    Context "When the repository does not exist" {
        try {
            Install-BoxstarterScripts $Boxstarter.LocalRepo
        }
        catch{
            $err = $_
        }

        It "Should throw a validation error"{
            $err.CategoryInfo.Category | should be "InvalidData"
        }
    }
}