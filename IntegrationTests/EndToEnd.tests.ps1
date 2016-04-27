$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. $here\test-helper.ps1
$secpasswd = ConvertTo-SecureString "Pass@word1" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

Describe "GistPackage" {
    $result = Invoke-RemoteBoxstarterRun -BaseDir $baseDir -VMName win2012r2 -Credential $credential -PackageName "https://gist.githubusercontent.com/mwrock/32030c56149138ad0c44/raw/32b6a80741404a3ab1a10ae3f5622b447e33c34a/gistfile1.txt"
    Write-Host ($result.Errors | Out-String)
    Write-Host ($result.Exceptions | Out-String)

    it "installed temp-package" {
        $result.InvokeOnTarget($result.Session, {
            Test-Path "c:\ProgramData\chocolatey\lib\temp_boxstarterPackage"
        }) | should be $true
    }
    it "had no errors" {
        $result.Errors | should BeNullOrEmpty
        $result.Exceptions.Count | should Be 0
    }
}

@("win2k8r2", "win2012r2") | % {
    Describe $_ {
        $vmName = $_
        $baseDir = "$here\..\"

        context "local" {
            $result = Invoke-LocalBoxstarterRun -BaseDir $baseDir -VMName $VMName -Credential $credential -PackageName test-package
            Write-Host ($result.Errors | Out-String)

            it "installed test-package" {
                $result.InvokeOnTarget($result.Session, {
                    Test-Path "c:\ProgramData\chocolatey\lib\test-package"
                }) | should be $true
            }

            it "enabled telnet" {
                $result.InvokeOnTarget($result.Session, {
                    (get-command telnet -ErrorAction SilentlyContinue) -ne $null
                }) | should be $true
            }

            it "installed force-reboot" {
                $result.InvokeOnTarget($result.Session, {
                    Test-Path "c:\ProgramData\chocolatey\lib\force-reboot"
                }) | should be $true
            }

            it "had no errors" {
                $result.Errors | should BeNullOrEmpty
            }

            it "rebooted" {
                $result.Rebooted | Should be $true
                Remove-PsSession $result.Session
            }
        }

        context "remote" {
            $result = Invoke-RemoteBoxstarterRun -BaseDir $baseDir -VMName $VMName -Credential $credential -PackageName test-package
            Write-Host ($result.Errors | Out-String)
            Write-Host ($result.Exceptions | Out-String)

            it "installed test-package" {
                $result.InvokeOnTarget($result.Session, {
                    Test-Path "c:\ProgramData\chocolatey\lib\test-package"
                }) | should be $true
            }

if($vmName -eq "win2012r2") {
            it "installed windirstat in task" {
                $result.InvokeOnTarget($result.Session, {
                    $log = Get-Content "$env:localappdata\boxstarter\boxstarter.log" | Out-String
                    $log.Contains("windirstatInstall.exe`"  in scheduled task")
                }) | should be $true
            }
}

            it "enabled telnet" {
                $result.InvokeOnTarget($result.Session, {
                    (get-command telnet -ErrorAction SilentlyContinue) -ne $null
                }) | should be $true
            }

            it "installed force-reboot" {
                $result.InvokeOnTarget($result.Session, {
                    Test-Path "c:\ProgramData\chocolatey\lib\force-reboot"
                }) | should be $true
            }

            it "had no errors" {
                $result.Errors | should BeNullOrEmpty
                $result.Exceptions.Count | should Be 0
            }

            it "rebooted" {
                $result.Rebooted | Should be $true
                Remove-PsSession $result.Session
            }
        }
    }
}

Describe "Invoke-ChocolateyBoxstarter via bootstrapper.bat (end to end)" {
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $here\..\BuildPackages\test-package2.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package2*" -force -recurse

        ."$here\..\boxstarter.bat" test-package2 -LocalRepo "$testRoot\Repo" -DisableReboots

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package2*" | Should Be $true
        }
    }
}

Describe "Chocolatey Package throws an Exception" {
    $testRoot = (Get-PSDrive TestDrive).Root

    Context "When exception is thrown from main package with no handling" {
        remove-Item $boxstarter.Log -Force
        $errorMsg="I am an error"
        Set-Content "$testRoot\test.txt" -Value "throw '$errorMsg'" -Force

        $result = Invoke-ChocolateyBoxstarter "$testRoot\test.txt" -LocalRepo "$testRoot\Repo" -DisableReboots 2>&1

        it "should log error" {
            $boxstarter.Log | Should Contain $errorMsg
        }
    }
}
