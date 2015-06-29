$here = Split-Path -Parent $MyInvocation.MyCommand.Path
import-module $here\..\boxstarter.Chocolatey\boxstarter.Chocolatey.psd1 -Force

Describe "Invoke-ChocolateyBoxstarter via bootstrapper.bat (end to end)" {
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $here\..\BuildPackages\test-package.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        Add-Content "$($Boxstarter.VendoredChocoPath)\ChocolateyInstall\ChocolateyInstall.log" -Value "______ test-package v1.0.0 ______" -force

        ."$here\..\boxstarter.bat" test-package -LocalRepo "$testRoot\Repo" -DisableReboots

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package.*" | Should Be $true
        }
        it "should have cleared previous logs" {
            $installLines = get-content "$($Boxstarter.VendoredChocoPath)\ChocolateyInstall\Install.log" | ? { $_ -like "Successfully installed 'test-package*" } 
            $installLines.Count | Should Be 1
        }          
    }
}

Describe "Chocolatey Package throws an Exception" {
    $testRoot = (Get-PSDrive TestDrive).Root

    Context "When exception is thrown from main package with no handling" {
        remove-Item $boxstarter.Log -Force
        $errorMsg="I am an error"
        Set-Content "$testRoot\test.txt" -Value "throw '$errorMsg'" -Force

        get-content "$testRoot\test.txt"
        $result = Invoke-ChocolateyBoxstarter "$testRoot\test.txt" -LocalRepo "$testRoot\Repo" -DisableReboots 2>&1

        it "should log error" {
            Get-Content "$testRoot\test.txt" | Should Match $errorMsg
        }
        it "should write error to error stream" {
            $result.Exception.Message | should be $errorMsg
        }          
    }

    Context "When exception is thrown from chocolatey" {
        remove-Item $boxstarter.Log -Force
        $errorMsg="I am another error"
        Set-Content "$testRoot\test.txt" -Value "try {throw '$errorMsg'}catch{Write-ChocolateyFailure 'testing' `$(`$_.Exception.Message);throw}" -Force

        $result = Invoke-ChocolateyBoxstarter "$testRoot\test.txt" -LocalRepo "$testRoot\Repo" -DisableReboots 2>&1

        it "should log error" {
            Get-Content "$testRoot\test.txt" | Should Match $errorMsg
        }
        it "should write error once" {
            $result.Count | should be 2
        }                  
        it "should write correct error to error stream" {
            $result[0].Exception.Message.Contains($errorMsg) | should be $true
        }          
    }
}
