$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Invoke-ChocolateyBoxstarter via bootstrapper.bat (end to end)" {
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $here\..\BuildPackages\test-package.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        Add-Content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -Value "______ test-package v1.0.0 ______" -force

        ."$here\..\boxstarter.bat" test-package -LocalRepo "$testRoot\Repo" -DisableReboots

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package.*" | Should Be $true
        }
        it "should have cleared previous logs" {
            $installLines = get-content "$env:ChocolateyInstall\ChocolateyInstall\Install.log" | ? { $_ -like "Successfully installed 'test-package*" } 
            $installLines.Count | Should Be 1
        }          
    }
}
