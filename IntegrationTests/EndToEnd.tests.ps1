$here = Split-Path -Parent $MyInvocation.MyCommand.Path
import-module $here\..\boxstarter.Hyperv\boxstarter.Hyperv.psd1 -Force
. $here\test-helper.ps1
$secpasswd = ConvertTo-SecureString "Pass@word1" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

Describe "Win2k8r2LocalRun" {
    $result = Invoke-LocalBoxstarterRun -BaseDir "$here\..\" -VMName win2k8r2 -Credential $credential -PackageName test-package

    it "installed test-package" {
        $result.InvokeOnTarget($result.Session, {
            Test-Path "c:\ProgramData\chocolatey\lib\test-package   "
        }) | should be $true
    }

    it "installed forced-reboot" {
        $result.InvokeOnTarget($result.Session, {
            Test-Path "c:\ProgramData\chocolatey\lib\force-reboot"
        }) | should be $true
    }

    it "had no errors" {
        $result.Errors | should BeNullOrEmpty
    }

    it "rebooted" {
        $result.Rebooted | Should be $true
    }
}

Describe "Invoke-ChocolateyBoxstarter via bootstrapper.bat (end to end)" {
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $here\..\BuildPackages\test-package.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse

        ."$here\..\boxstarter.bat" test-package -LocalRepo "$testRoot\Repo" -DisableReboots

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package.*" | Should Be $true
        }
    }
}

Describe "Install-BoxstarterPackage" {
    $testRoot = (Get-PSDrive TestDrive).Root
    $oldChoco = $env:ChocolateyInstall
    $env:ChocolateyInstall = "$testRoot\choco"
    $repo = "$testRoot\Repo"
    mkdir $repo -ErrorAction SilentlyContinue | Out-Null
    mkdir $env:ChocolateyInstall -ErrorAction SilentlyContinue | Out-Null
    
    Copy-Item $here\..\BuildPackages\test-package.*.nupkg $repo
    Copy-Item $oldChoco\choco.exe $env:ChocolateyInstall

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse -ErrorAction SilentlyContinue

        $result = Install-BoxstarterPackage -PackageName test-package -LocalRepo "$testRoot\Repo" -DisableReboots

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package" | Should Be $true
        }
        it "should not have errors" {
            $result.errors.count | Should Be 0
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
