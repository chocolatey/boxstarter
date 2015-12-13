$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }

$Boxstarter.BaseDir=(split-path -parent (split-path -parent $here))
$Boxstarter.SuppressLogging=$true
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }

function DISM { return; }

Describe "Getting-Chocolatey" {
    Mock Call-Chocolatey {$global:LASTEXITCODE=0}
    Mock Invoke-Reboot
    Mock Test-PendingReboot {return $false}
    $pkgDir = "$env:ChocolateyInstall\lib\pkg"
    Mock Test-Path  { $true } -ParameterFilter {$path -eq $pkgDir}

    Context "When a reboot is pending and reboots are OK" {
        Mock Test-PendingReboot {$true}
        $boxstarter.RebootOk=$true
        
        Chocolatey Install pkg

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will not get Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 0
        }        
    }

    Context "When Boxstarter is restarting from a nested package" {
        $Boxstarter.IsRebooting=$true
        $boxstarter.RebootOk=$true
        
        Chocolatey Install pkg

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will not get Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 0
        }
        $Boxstarter.IsRebooting=$false
    }

    Context "When a reboot is pending but reboots are not OK" {
        Mock Test-PendingReboot {$true}
        $boxstarter.RebootOk=$false
        
        Chocolatey Install pkg

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
        it "will get Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 1
        }        
    }

    Context "When chocolatry strips the machine module path" {
        Mock Call-Chocolatey {
            $env:PSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath","User")
            $global:LASTEXITCODE=0
        }

        Chocolatey Install pkg

        it "will append machine module path" {
            $env:PSModulePath.EndsWith([System.Environment]::GetEnvironmentVariable("PSModulePath","Machine")) | should be $true
        }        
    }

    Context "When Installing multiple packages" {
        $packages=@("package1","package2")
        
        Chocolatey Install $packages

        it "will get chocolatey for package1" {
            Assert-MockCalled Call-Chocolatey -ParameterFilter {$packageNames -eq "package1"} -times 1
        }        
        it "will get chocolatey for package2" {
            Assert-MockCalled Call-Chocolatey -ParameterFilter {$packageNames -eq "package2"} -times 1
        }        
    }

    Context "When chocolatey throws a reboot error and reboots are OK" {
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Call-Chocolatey {throw "[ERROR] Exit code was '3010'."}

        Chocolatey Install pkg -RebootCodes @(56,3010,654) 2>&1 | out-null

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When chocolatey writes a reboot error and reboots are OK" {
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Call-Chocolatey {Write-Error "[ERROR] Exit code was '-654'."}
        
        Chocolatey Install pkg -RebootCodes @(56,3010,-654) 2>&1 | out-null

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When user specifies a reboot code" {
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Call-Chocolatey {throw "[ERROR] Exit code was '3010'." }
        
        Chocolatey Install pkg -RebootCodes @(56,-654) 2>&1 | out-null

        it "will Invoke-Reboot when a default code is called too" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder when a default code is called too" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When chocolatey writes a error that is not a reboot error" {
        $boxstarter.RebootOk=$true
        Mock Call-Chocolatey {Write-Error "[ERROR] Exit code was '3020'." 2>&1 | out-null}

        Chocolatey Install pkg -RebootCodes @(56,3010,654) | out-null

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
    }

    Context "When WindowsFeature is already installed" {
        Mock DISM {"State : Enabled"}
        
        Chocolatey Install "somefeature" -source "WindowsFeatures" | out-null

        it "will not Call Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 0
        }
    }   

    Context "When WindowsFeature is not already installed" {       
        Chocolatey Install "somefeature" -source "WindowsFeatures" | out-null

        it "will Call Chocolatey" {
            Assert-MockCalled Call-Chocolatey
        }
    }

    Context "When a reboot was triggered" {
        Mock Call-Chocolatey { $Boxstarter.IsRebooting=$true }
        $boxstarter.RebootOk=$true
        Mock Remove-Item

        Chocolatey Install pkg | out-null

        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When chocolatey returns an erroneous exit code" {
        Mock Call-Chocolatey {[System.Environment]::ExitCode=1}
        $Boxstarter.IsRebooting=$false
        
        $error = Chocolatey Install pkg 2>&1

        it "will write a warning" {
            $error| should match "Chocolatey reported an unsuccessful exit code of 1"
        }
        [System.Environment]::ExitCode=0
    }

    Context "When a reboot is not pending" {       
        Chocolatey Install pkg

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
        it "will get Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 1
        }        
    }
}

Describe "Call-Chocolatey" {
    Mock Invoke-Reboot
    Mock Test-PendingReboot {return $false}

    context "when dot net version is less than 4 and remote" {
        $currentCLR = $PSVersionTable.CLRVersion
        Mock Get-IsRemote { return $true }
        $script:passedCommand = ""
        Mock Invoke-FromTask { $script:passedCommand=$command } -ParameterFilter { $DotNetVersion -eq "v4.0.30319" }
        $PSVersionTable.CLRVersion = New-Object Version '2.0.0'

        Call-Chocolatey Install @("pkg1","pkg2") -source blah

        it "invoke from task .net 4 task" {
            $script:passedCommand -like "*Invoke-Chocolatey @(`"Install`",@(`"pkg1`",`"pkg2`"),`"-source`",`"blah`",`"-y`")" | Should Be $true
        }
        $PSVersionTable.CLRVersion = $currentCLR
    }

    context "when dot net version is 4" {
        $currentCLR = $PSVersionTable.CLRVersion
        Mock Invoke-FromTask
        Mock Invoke-LocalChocolatey
        $PSVersionTable.CLRVersion = New-Object Version '4.0.0'

        Call-Chocolatey Install pkg

        it "do not invoke from task" {
            Assert-MockCalled Invoke-FromTask -times 0
        }
        $PSVersionTable.CLRVersion = $currentCLR
    }

    context "when remote" {
        Mock Invoke-FromTask
        Mock Invoke-LocalChocolatey
        Mock Get-IsRemote { return $true }

        Call-Chocolatey Install pkg

        it "do not invoke from task" {
            Assert-MockCalled Invoke-FromTask -times 0
        }
    }

    context "when passing normal args" {
        $script:passedArgs = ""
        Mock Get-BoxstarterConfig { @{NugetSources="blah"} }
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg

        it "passes expected params" {
            $passedArgs.count | Should Be 5
        }
        it "passes thru command" {
            $passedArgs[0] | Should Be "Install"
        }
        it "passes thru package" {
            $passedArgs[1] | Should Be "pkg"
        }
        it "passes configed source" {
            $passedArgs[2] | Should Be "-source"
            $passedArgs[3] | Should Be "$($Boxstarter.LocalRepo);blah"
        }
        it "passes confirm" {
            $passedArgs[4] | Should Be "-y"
        }
    }

    context "when not calling install or update" {
        $script:passedArgs = ""
        Mock Get-BoxstarterConfig { @{NugetSources="blah"} }
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Uninstall pkg

        it "passes expected params" {
            $passedArgs.count | Should Be 3
        }
        it "passes thru command" {
            $passedArgs[0] | Should Be "Uninstall"
        }
        it "passes thru package" {
            $passedArgs[1] | Should Be "pkg"
        }
        it "passes confirm" {
            $passedArgs[2] | Should Be "-y"
        }
    }

    context "when passing source as --source" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg --source blah --bing boom

        it "passes expected params" {
            $passedArgs.count | Should Be 7
        }
        it "passes source" {
            $passedArgs[2] | Should Be "--source"
            $passedArgs[3] | Should Be "blah"
        }
        it "passes other args" {
            $passedArgs[4] | Should Be "--bing"
            $passedArgs[5] | Should Be "boom"
        }

    }

    context "when passing source as -source" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg -source blah

        it "passes expected params" {
            $passedArgs.count | Should Be 5
        }
        it "passes source" {
            $passedArgs[2] | Should Be "-source"
            $passedArgs[3] | Should Be "blah"
        }
    }

    context "when passing source as -s" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg -s blah

        it "passes expected params" {
            $passedArgs.count | Should Be 5
        }
        it "passes source" {
            $passedArgs[2] | Should Be "-s"
            $passedArgs[3] | Should Be "blah"
        }
    }

    context "when passing force as -force:`$true" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg -force:$true

        it "passes expected params" {
            $passedArgs.count | Should Be 6
        }
        it "passes source" {
            $passedArgs[2] | Should Be "-f"
        }
    }

    context "when passing force as -force:`$false" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg -force:$false

        it "passes expected params" {
            $passedArgs.count | Should Be 5
        }
        it "passes source" {
            $passedArgs -contains "-f" | Should Be $false
        }
    }

    context "when passing force as -f" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg -f

        it "passes expected params" {
            $passedArgs.count | Should Be 6
        }
        it "passes source" {
            $passedArgs[2] | Should Be "-f"
        }
    }

    context "when verbose" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }
        $global:VerbosePreference="Continue"
        choco Install pkg
        $global:VerbosePreference="SilentlyContinue"

        it "passes expected params" {
            $passedArgs.count | Should Be 6
        }
        it "passes source" {
            $passedArgs[4] | Should Be "-Verbose"
        }
    }
}

Describe "Install-ChocolateyInstallPackageOverride" {
    Mock Get-IsRemote { return $true }
    $script:passedCommand = ""
    Mock Invoke-FromTask { $script:passedCommand=$command }

    Install-ChocolateyInstallPackageOverride -packageName pkg -silentArgs "/s" -file "myfile.exe" -validExitCodes @(1,2,3)

    it "passes command params to task" {
        $script:passedCommand -like "*Install-ChocolateyInstallPackage -packageName `"pkg`" -silentArgs `"/s`" -file `"myfile.exe`" -validExitCodes @(1,2,3)*" | Should Be $true
    }
}

Describe "Export-BoxstarterVars" {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
            /RU "$($identity.Name)" /IT `
    /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
            Out-Null
    $global:Boxstarter.Var1 = "val1"
    $global:Boxstarter.Var2 = $true
    $global:Boxstarter.Val3 = $null
    $script:out = ""
    Mock write-host {
        $script:out += $object
    }

    Invoke-FromTask @"
        Import-Module $($boxstarter.BaseDir)\boxstarter.chocolatey\Boxstarter.chocolatey.psd1 -DisableNameChecking
        $(Serialize-BoxstarterVars)
        `$global:Boxstarter.TaskPid = "`$PID"
        Export-BoxstarterVars
        PowerShell -Command {
            Import-Module '$($boxstarter.BaseDir)\Boxstarter.chocolatey\Boxstarter.chocolatey.psd1' -DisableNameChecking -ArgumentList `$true
            `$Boxstarter | ConvertTo-Json | Write-Output
        } 
"@
    $boxstarterJson = ConvertFrom-Json $script:out

    it "exports string variable" {
        $boxstarterJson.Var1 | Should Be "val1"
    }
    it "exports boolean variable" {
        $boxstarterJson.Var2 | Should Be $true
    }
    it "does not export null variable" {
        $boxstarterJson.psobject.properties.match("Var3") | Should Be $null
    }
    it "exports source pid" {
        $boxstarterJson.SourcePid | Should Be $boxstarterJson.TaskPid
    }

    schtasks /DELETE /TN 'Boxstarter Task' /F 2>&1 | Out-null
}