$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(Get-Module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}
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

    Context "When Chocolatey strips the machine module path" {
        Mock Call-Chocolatey {
            $env:PSModulePath = "C:\Program Files\WindowsPowerShell\Modules"
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

        it "will get Chocolatey for package1" {
            Assert-MockCalled Call-Chocolatey -ParameterFilter {$PackageNames -eq "package1"} -times 1
        }
        it "will get Chocolatey for package2" {
            Assert-MockCalled Call-Chocolatey -ParameterFilter {$PackageNames -eq "package2"} -times 1
        }
    }

    Context "When Chocolatey throws a reboot error and reboots are OK" {
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Call-Chocolatey {throw "[ERROR] Exit code was '3010'."}

        Chocolatey Install pkg -RebootCodes @(56,3010,654) 2>&1 | Out-Null

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When Chocolatey writes a reboot error and reboots are OK" {
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Call-Chocolatey {Write-Error "[ERROR] Exit code was '-654'."}

        Chocolatey Install pkg -RebootCodes @(56,3010,-654) 2>&1 | Out-Null

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

        Chocolatey Install pkg -RebootCodes @(56,-654) 2>&1 | Out-Null

        it "will Invoke-Reboot when a default code is called too" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder when a default code is called too" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When Chocolatey writes a error that is not a reboot error" {
        $boxstarter.RebootOk=$true
        Mock Call-Chocolatey {Write-Error "[ERROR] Exit code was '3020'." 2>&1 | Out-Null}

        Chocolatey Install pkg -RebootCodes @(56,3010,654) | Out-Null

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
    }

    Context "When WindowsFeature is already installed" {
        Mock DISM {"State : Enabled"}

        Chocolatey Install "somefeature" -source "WindowsFeatures" | Out-Null

        it "will not Call Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 0
        }
    }

    Context "When WindowsFeature is not already installed" {
        Chocolatey Install "somefeature" -source "WindowsFeatures" | Out-Null

        it "will Call Chocolatey" {
            Assert-MockCalled Call-Chocolatey
        }
    }

    Context "When a reboot was triggered" {
        Mock Call-Chocolatey { $Boxstarter.IsRebooting=$true }
        $boxstarter.RebootOk=$true
        Mock Remove-Item

        Chocolatey Install pkg | Out-Null

        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq $pkgDir}
        }
    }

    Context "When Chocolatey returns an erroneous exit code" {
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

        it "executes with success" {
            choco Install pkg 
            $LASTEXITCODE | Should Be 0
        }

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

        choco Install pkg --source blah --bing=boom

        it "passes expected params" {
            $passedArgs.count | Should Be 7
        }
        it "passes source" {
            $passedArgs[2] | Should Be "--source"
            $passedArgs[3] | Should Be "blah"
        }
        it "passes other args with assignment operator" {
            $passedArgs[4] | Should Be "--bing"
            $passedArgs[5] | Should Be "boom"
        }
    }

    context "when passing source as --source with =" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg --source=blah

        it "passes expected params" {
            $passedArgs.count | Should Be 5
        }
        it "passes source" {
            $passedArgs[2] | Should Be "--source"
            $passedArgs[3] | Should Be "blah"
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
    
    context "when passing force as -force" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install pkg -force

        it "passes expected params" {
            $passedArgs.count | Should Be 6
        }
        it "passes source" {
            $passedArgs[2] | Should Be "-force"
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
            $passedArgs[0] | Should Be "Install"
            $passedArgs[1] | Should Be "pkg"
            $passedArgs[2] | Should Be "-Source"
            # $passedArgs[3] -> feeds, may differ from system to system
            $passedArgs[4] | Should Be "-Verbose"
            $passedArgs[5] | Should Be "-y"
        }
    }

    context "package parameters / -Verbose" {
        $script:passedArgs = ""
        Mock Invoke-LocalChocolatey { $script:passedArgs = $chocoArgs }

        choco Install -y pkg --source blah --installargs "ADD_CMAKE_TO_PATH=System" -Verbose

        $passedArgs | Should Not BeNullOrEmpty

        it "passes expected params" {
            $passedArgs.count | Should Be 8 # actually 7 + 1 "-Verbose" is appended
        }
        it "passes all parameters in correct order" {
            $passedArgs[0] | Should Be "Install"
            $passedArgs[1] | Should Be "pkg" # package will always be first argument (reordering happens!)
            $passedArgs[2] | Should Be "-y" # passed -y is after package because of the reordering
            $passedArgs[3] | Should Be "--source"
            $passedArgs[4] | Should Be "blah"
            $passedArgs[5] | Should Be "--installargs"
            $passedArgs[6] | Should Be "ADD_CMAKE_TO_PATH=System"
            $passedArgs[7] | Should Be "-Verbose"
        }
    }
}

Describe "Get-PackageNamesFromInvocationLine" {
    It "extracts single package name from default invocation style" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-y", "-f", "packagename", "-s", "myfeed")
        $pkgNames | Should Be "packagename"
    }
    It "extracts multipe package names from default invocation style" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-y", "-f", "packagename1", "pkg2", "-s", "myfeed")
        $pkgNames | Should Be @("packagename1", "pkg2")
    }
    It "extracts multipe package names from complex invocation" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("--execution-timeout", "600", "-y", "-cache-location", "d:/cache", "-f", "packagename1", "-maxdownloadrate=1200", "-ia", "/S /noreboot", "pkg2", "-s", "myfeed")
        $pkgNames | Should Be @("packagename1", "pkg2")
    }
    It "keeps sort order of packages names" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-y", "foobar", "-f", "packagename1", "pkg2", "-s", "myfeed")
        $pkgNames | Should Be @("foobar", "packagename1", "pkg2")
    }
    It "ignores anything that starts with a dash" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-foo=bar", "-pkg1", "-pkg2=???")
        $pkgNames | Should BeNullOrEmpty
    }
    It "ignores any parameter that contains a '='" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-foo=bar", "pkg1", "-pkg2=???")
        $pkgNames | Should Be "pkg1"
    }
    It "ignores any parameter that contains a '=' (weird case)" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-foo", "=", "bar", "pkg1", "-pkg2=???")
        $pkgNames | Should Be "pkg1"
    }
    It "ignores any parameter that contains a '=' (paranoid case)" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-a=", "paranoid", "-foo", "=", "bar", "pkg1", "-pkg2=???")
        $pkgNames | Should Be @("pkg1")
    }
    It "ignores any parameter that contains a '=' (paranoid case x paranoid case)" {
        $pkgNames = Get-PackageNamesFromInvocationLine @("-a=", "paranoid", "-foo", "=", "bar", @("-a=paranoid"), "pkg1", @("-a", "=", "paranoid"), "-pkg2=???")
        $pkgNames | Should Be @("pkg1")
    }
}

Describe "Install-ChocolateyInstallPackageOverride" {
    Mock Get-IsRemote { return $true }
    $script:passedCommand = ""
    [Int64]$i64 = [Int32]::MaxValue + 1
    Mock Invoke-FromTask { $script:passedCommand=$command }

    Install-ChocolateyInstallPackageOverride -packageName pkg -silentArgs "/s" -file "myfile.exe" -validExitCodes @(1,2,$i64)

    it "passes command params to task" {
        $script:passedCommand -like "*Install-ChocolateyInstallPackage -packageName `"pkg`" -silentArgs `"/s`" -file `"myfile.exe`" -validExitCodes @(1,2,$i64)*" | Should Be $true
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
    Mock Write-Host {
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
