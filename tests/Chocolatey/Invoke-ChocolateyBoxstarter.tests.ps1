$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

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
        it "should not call chocolatey" {
            Assert-MockCalled chocolatey -times 0
        }          
    }

    Context "When calling normally" {
        Mock New-PackageFromScript {return "somePackage"} -ParameterFilter {$source -eq "TestDrive:\package.txt"}
        Mock Chocolatey
        New-Item TestDrive:\package.txt -type file | Out-Null

        Invoke-ChocolateyBoxstarter TestDrive:\package.txt -NoPassword | out-null

        it "should concatenate local repo and nuget sources for source param to chocolatey" {
            Assert-MockCalled chocolatey -ParameterFilter {$source -eq "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"}
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
        it "should call chocolatey" {
            Assert-MockCalled chocolatey
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

        Invoke-ChocolateyBoxstarter TestDrive:\package.txt -NoPassword | out-null

        it "should use package returned from ScriptFromPackage" {
            Assert-MockCalled chocolatey -ParameterFilter {$packageNames -eq "somePackage"}
        }
    }

    Context "When specifying a http Uri instead of a package" {
        Mock New-PackageFromScript {return "somePackage"} -ParameterFilter {$source -eq "http://someurl"}
        Mock Chocolatey

        Invoke-ChocolateyBoxstarter http://someurl -NoPassword | out-null

        it "should use package returned from ScriptFromPackage" {
            Assert-MockCalled chocolatey -ParameterFilter {$packageNames -eq "somePackage"}
        }
    }

    Context "When specifying a package that is also a directory name" {
        Mock New-PackageFromScript
        Mock Chocolatey
        New-Item TestDrive:\package -type directory | Out-Null

        Invoke-ChocolateyBoxstarter "TestDrive:\package" -NoPassword | out-null

        it "should not use package from ScriptFromPackage" {
            Assert-MockCalled New-PackageFromScript -times 0
        }
        it "should use package as is" {
            Assert-MockCalled chocolatey -ParameterFilter {$packageNames -eq "TestDrive:\package"}
        }        
    }

    Context "When specifying multiple packages" {
        Mock Chocolatey
        $packages=@("package1","package2")

        Invoke-ChocolateyBoxstarter $packages -NoPassword | out-null

        it "should pass both packages to chocolatey" {
            Assert-MockCalled chocolatey -ParameterFilter { (Compare-Object $packageNames $packages) -eq $null }
        }
    }

}
