$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }

Describe "New-PackageFromScript" {
    $Boxstarter.BaseDir=(Get-PSDrive TestDrive).Root
    $Boxstarter.LocalRepo=Join-Path $boxstarter.BaseDir "repo"
    $Boxstarter.SuppressLogging=$true
    Mock Write-Host -parameterFilter {$ForegroundColor -eq $null}

    Context "When Building a script from a file" {
        New-Item TestDrive:\script.ps1 -type file -Value "return" | Out-Null

        ($result = New-PackageFromScript TestDrive:\script.ps1) | Out-Null

        It "Will Create the nupkg" {
            Join-Path $Boxstarter.LocalRepo "$result.1.0.0.nupkg" | Should Exist
        }
        It "Will contain the script" {
            Rename-Item "$($boxstarter.LocalRepo)\$result.1.0.0.nupkg" "$($boxstarter.LocalRepo)\$result.1.0.0.zip" 
            $shell_app=new-object -com shell.application
            $filename = "$result.1.0.0.zip"
            $zip_file = $shell_app.namespace("$($boxstarter.LocalRepo)\$filename")
            $destination = $shell_app.namespace($boxstarter.BaseDir)
            $destination.Copyhere($zip_file.items())
            Get-content "$($boxstarter.BaseDir)\tools\ChocolateyInstall.ps1" | Should be "return"
        }
    }

    Context "When Building a script from a URL" {
        . "$env:chocolateyinstall\helpers\functions\Get-WebFile.ps1"
        Mock Get-WebFile {return "return"}

        ($result = New-PackageFromScript "file://$($boxstarter.Basedir)/script.ps1") | Out-Null

        It "Will Create the nupkg" {
            Join-Path $Boxstarter.LocalRepo "$result.1.0.0.nupkg" | Should Exist
        }
        It "Will contain the script" {
            Rename-Item "$($boxstarter.LocalRepo)\$result.1.0.0.nupkg" "$($boxstarter.LocalRepo)\$result.1.0.0.zip" 
            $shell_app=new-object -com shell.application
            $filename = "$result.1.0.0.zip"
            $zip_file = $shell_app.namespace("$($boxstarter.LocalRepo)\$filename")
            $destination = $shell_app.namespace($boxstarter.BaseDir)
            $destination.Copyhere($zip_file.items())
            Get-content "$($boxstarter.BaseDir)\tools\ChocolateyInstall.ps1" | Should be "return"
        }
    }

    Context "When http client throws an error" {
        . "$env:chocolateyinstall\helpers\functions\Get-WebFile.ps1"
        Mock Get-WebFile {throw "blah"}
        Mock New-BoxstarterPackage

        try {($result = New-PackageFromScript "file://$($boxstarter.Basedir)/script.ps1") | Out-Null}catch{}

        It "Will not try to create package" {
            Assert-MockCalled New-BoxstarterPackage -Times 0
        }
    }
    
    Context "When script file is not found" {
        Mock New-BoxstarterPackage

        try {($result = New-PackageFromScript TestDrive:\script.ps1) | Out-Null}catch{}

        It "Will not try to create package" {
            Assert-MockCalled New-BoxstarterPackage -Times 0
        }
    }

    Context "When ReBuilding an existing package" {
        New-Item TestDrive:\script.ps1 -type file -Value "return" | Out-Null
        New-PackageFromScript TestDrive:\script.ps1 | Out-Null
        New-Item TestDrive:\script.ps1 -type file -Value "return 'again'" -force | Out-Null

        ($result = New-PackageFromScript TestDrive:\script.ps1) | Out-Null

        It "Will contain the new script" {
            Rename-Item "$($boxstarter.LocalRepo)\$result.1.0.0.nupkg" "$($boxstarter.LocalRepo)\$result.1.0.0.zip" 
            $shell_app=new-object -com shell.application
            $filename = "$result.1.0.0.zip"
            $zip_file = $shell_app.namespace("$($boxstarter.LocalRepo)\$filename")
            $destination = $shell_app.namespace($boxstarter.BaseDir)
            $destination.Copyhere($zip_file.items())
            Get-content "$($boxstarter.BaseDir)\tools\ChocolateyInstall.ps1" | Should be "return 'again'"
        }
    }

}