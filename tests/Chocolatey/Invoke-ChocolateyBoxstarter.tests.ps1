$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(Get-Module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

Resolve-Path $here\..\..\boxstarter.common\*.ps1 |
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.winconfig\*.ps1 |
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.bootstrapper\*.ps1 |
    % { . $_.ProviderPath }
$Boxstarter.BaseDir=(split-path -parent (split-path -parent $here))
$Boxstarter.SuppressLogging=$true
Resolve-Path $here\..\..\boxstarter.chocolatey\*.ps1 |
    % { . $_.ProviderPath }

Describe "Invoke-ChocolateyBoxstarter" {
    Context "When not invoked via boxstarter" {
        $Boxstarter.ScriptToCall=$null
        Mock Invoke-Boxstarter
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter package

        it "should Call Boxstarter" {
            Assert-MockCalled Invoke-Boxstarter
        }
        it "should not call Chocolatey" {
            Assert-MockCalled Chocolatey -times 0
        }
    }

    Context "When calling normally" {
        Mock New-PackageFromScript {return "somePackage"} -ParameterFilter {$source -eq "TestDrive:\package.txt"}
        $script:passedSource = ""
        Mock Chocolatey { $script:passedSource = $args[5] }
        New-Item TestDrive:\package.txt -type file | Out-Null

        Invoke-ChocolateyBoxstarter TestDrive:\package.txt -NoPassword | Out-Null

        it "should concatenate local repo and NuGet sources for source param to Chocolatey" {
            $script:passedSource | Should Be "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"
        }
    }

    Context "When not invoked via boxstarter and given a password" {
        $Boxstarter.ScriptToCall=$null
        Mock Invoke-Boxstarter
        Mock Chocolatey
        $securePassword = (ConvertTo-SecureString "mypassword" -asplaintext -force)

        Invoke-ChocolateyBoxstarter package -password $securePassword

        it "should Call Boxstarter with the password" {
            Assert-MockCalled Invoke-Boxstarter -ParameterFilter {$password -eq $securePassword}
        }
    }

    Context "When not invoked via boxstarter and passing NoPassword" {
        $Boxstarter.ScriptToCall=$null
        Mock Invoke-Boxstarter
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter package -NoPassword

        it "should Call Boxstarter with NoPassword" {
            Assert-MockCalled Invoke-Boxstarter -ParameterFilter {$Nopassword -eq $True}
        }
    }

    Context "When invoked via boxstarter" {
        $Boxstarter.ScriptToCall="return"
        Mock Invoke-Boxstarter
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter package

        it "should not Call Boxstarter" {
            Assert-MockCalled Invoke-Boxstarter -times 0
        }
        it "should call Chocolatey" {
            Assert-MockCalled Chocolatey
        }
    }

    Context "When Setting a LocalRepo on $Boxstarter and not the commandLine" {
        $Boxstarter.ScriptToCall="return"
        $Boxstarter.LocalRepo="myrepo"
        Mock Invoke-Boxstarter
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter package

        it "should use Boxstarter.Localrepo value" {
            $Boxstarter.LocalRepo | should be "myrepo"
        }
    }

    Context "When Setting a LocalRepo on the commandLine" {
        $Boxstarter.ScriptToCall="return"
        $Boxstarter.LocalRepo="myrepo"
        Mock Invoke-Boxstarter
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter package -Localrepo "c:\anotherRepo"

        it "should use command line value" {
            $Boxstarter.LocalRepo | should be "c:\anotherRepo"
        }
    }

    Context "When specifying a file instead of a package" {
        Mock New-PackageFromScript {return "somePackage"} -ParameterFilter {$source -eq "TestDrive:\package.txt"}
        Mock Chocolatey
        New-Item TestDrive:\package.txt -type file | Out-Null

        Invoke-ChocolateyBoxstarter TestDrive:\package.txt -NoPassword | Out-Null

        it "should use package returned from ScriptFromPackage" {
            Assert-MockCalled Chocolatey -ParameterFilter {$PackageNames -eq "somePackage"}
        }
    }

    Context "When specifying a http Uri instead of a package" {
        Mock New-PackageFromScript {return "somePackage"} -ParameterFilter {$source -eq "http://someurl"}
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter http://someurl -NoPassword | Out-Null

        it "should use package returned from ScriptFromPackage" {
            Assert-MockCalled Chocolatey -ParameterFilter {$PackageNames -eq "somePackage"}
        }
    }

    Context "When specifying a package that is also a directory name" {
        Mock New-PackageFromScript
        Mock Chocolatey
        New-Item TestDrive:\package -type directory | Out-Null

        Invoke-ChocolateyBoxstarter "TestDrive:\package" -NoPassword | Out-Null

        it "should not use package from ScriptFromPackage" {
            Assert-MockCalled New-PackageFromScript -times 0
        }
        it "should use package as is" {
            Assert-MockCalled Chocolatey -ParameterFilter {$PackageNames -eq "TestDrive:\package"}
        }
    }

    Context "When specifying multiple packages" {
        Mock Chocolatey
        $packages=@("package1","package2")

        Invoke-ChocolateyBoxstarter $packages -NoPassword | Out-Null

        it "should pass both packages to Chocolatey" {
            Assert-MockCalled Chocolatey -ParameterFilter { (Compare-Object $PackageNames $packages) -eq $null }
        }
    }

}
