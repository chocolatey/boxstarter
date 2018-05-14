$here = Split-Path -Parent $MyInvocation.MyCommand.Path
import-module "$here\..\..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1" -Force

Describe "Get-BoxstarterConfig" {
    $testRoot=(Get-PSDrive TestDrive).Root
    $currentBase = $Boxstarter.BaseDir
    $currentNugetSources = $Boxstarter.NugetSources
    $currentLocalRepo = $Boxstarter.LocalRepo
    [xml]$configXml = Get-Content (Join-Path $Boxstarter.BaseDir BoxStarter.config)
    $Boxstarter.BaseDir = $testRoot

    Context "When No LocalRepo is explicitly configured" {
        Copy-Item "$currentBase\Boxstarter.Config" $testRoot

        $result = Get-BoxstarterConfig

        It "LocalRepo config value will equal the BuildPackages directory under base"{
            $result.LocalRepo | Should be (Join-Path $Boxstarter.BaseDir BuildPackages)
        }
    }

    Context "When NugetSorces have not been changed" {
        Copy-Item "$currentBase\Boxstarter.Config" $testRoot

        $result = Get-BoxstarterConfig

        It "NugetSources will be the same as those in the original file"{
            $result.NugetSources | Should be $configXml.config.NugetSources
        }
    }

    Context "When Setting NugetSorces to a new value" {
        Copy-Item "$currentBase\Boxstarter.Config" $testRoot
        $expected = "Some NuGet Source"

        Set-BoxstarterConfig -NugetSources $expected

        It "Get-BoxstarterConfig will reflect the set NugetSources"{
            (Get-BoxstarterConfig).NugetSources | Should be $expected
        }
        It "`$Boxstarter.NugetSources will reflect the set NugetSources"{
            $Boxstarter.NugetSources | Should be $expected
        }
    }

    Context "When Setting LocalRepo to a new value" {
        Copy-Item "$currentBase\Boxstarter.Config" $testRoot
        $expected = "$testRoot\CrazyRepo"

        Set-BoxstarterConfig -LocalRepo $expected

        It "Get-BoxstarterConfig will reflect the set LocalRepo"{
            (Get-BoxstarterConfig).LocalRepo | Should be $expected
        }
        It "`$Boxstarter.LocalRepo will reflect the set LocalRepo"{
            $Boxstarter.LocalRepo | Should be $expected
        }
    }

    Context "When Setting LocalRepo to a relative path" {
        Copy-Item "$currentBase\Boxstarter.Config" $testRoot
        $expected = "$testRoot\CrazyRepo"
        Push-Location $testRoot

        Set-BoxstarterConfig -LocalRepo ".\CrazyRepo"
        pop-Location

        It "Get-BoxstarterConfig will reflect the absolute path"{
            (Get-BoxstarterConfig).LocalRepo | Should be $expected
        }
    }

    $Boxstarter.BaseDir = $currentBase
    $Boxstarter.NugetSources = $currentNugetSources
    $Boxstarter.LocalRepo = $currentLocalRepo
}
