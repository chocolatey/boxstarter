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
Intercept-Chocolatey

function DISM { return; }

Describe "Getting-Chocolatey" {
    Mock Call-Chocolatey {$global:LASTEXITCODE=0}

    Context "When a reboot is pending and reboots are ok" {
        Mock Test-PendingReboot {$true}
        $boxstarter.RebootOk=$true
        Mock Invoke-Reboot
        
        Chocolatey Install pkg

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will not get chocolatry" {
            Assert-MockCalled Call-Chocolatey -times 0
        }        
    }

    Context "When a reboot is pending but reboots are not ok" {
        Mock Test-PendingReboot {$true}
        $boxstarter.RebootOk=$false
        Mock Invoke-Reboot
        
        Chocolatey Install pkg

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
        it "will get chocolatry" {
            Assert-MockCalled Call-Chocolatey -times 1
        }        
    }

    Context "When a reboot is not pending" {
        Mock Test-PendingReboot {return $false}
        Mock Invoke-Reboot
        
        Chocolatey Install pkg

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
        it "will get chocolatry" {
            Assert-MockCalled Call-Chocolatey -times 1
        }        
    }

    Context "When Installing multiple packages" {
        Mock Test-PendingReboot {return $false}
        Mock Invoke-Reboot
        $packages=@("package1","package2")
        
        Chocolatey Install $packages

        it "will get chocolatey for package1" {
            Assert-MockCalled Call-Chocolatey -ParameterFilter {$packageNames -eq "package1"} -times 1
        }        
        it "will get chocolatey for package2" {
            Assert-MockCalled Call-Chocolatey -ParameterFilter {$packageNames -eq "package2"} -times 1
        }        
    }

    Context "When chocolatey writes a reboot error and reboots are ok" {
        Mock Test-PendingReboot {return $false}
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Get-ChildItem {@("dir1","dir2")} -parameterFilter {$path -match "\\lib\\pkg.*"}
        Mock Invoke-Reboot
        Mock Call-Chocolatey {throw "[ERROR] Exit code was '3010'."}
        
        Chocolatey Install pkg -RebootCodes @(56,3010,654) 2>&1 | out-null

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq "dir2"}
        }
    }

    Context "When chocolatey writes a negative reboot error and reboots are ok" {
        Mock Test-PendingReboot {return $false}
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Get-ChildItem {@("dir1","dir2")} -parameterFilter {$path -match "\\lib\\pkg.*"}
        Mock Invoke-Reboot
        Mock Call-Chocolatey {throw "[ERROR] Exit code was '-654'."}
        
        Chocolatey Install pkg -RebootCodes @(56,3010,-654) 2>&1 | out-null

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq "dir2"}
        }
    }

    Context "When user specifies a reboot code" {
        Mock Test-PendingReboot {return $false}
        $boxstarter.RebootOk=$true
        Mock Remove-Item
        Mock Get-ChildItem {@("dir1","dir2")} -parameterFilter {$path -match "\\lib\\pkg.*"}
        Mock Invoke-Reboot
        Mock Call-Chocolatey {throw "[ERROR] Exit code was '3010'." }
        
        Chocolatey Install pkg -RebootCodes @(56,-654) 2>&1 | out-null

        it "will Invoke-Reboot when a default code is called too" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will delete package folder when a default code is called too" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq "dir2"}
        }
    }

    Context "When chocolatey writes a error that is not a reboot error" {
        Mock Test-PendingReboot {return $false}
        $boxstarter.RebootOk=$true
        Mock Invoke-Reboot
        Mock Call-Chocolatey {Write-Error "[ERROR] Exit code was '3020'." 2>&1 | out-null}
        
        Chocolatey Install pkg -RebootCodes @(56,3010,654) | out-null

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
    }

    Context "When WindowsFeature is already installed" {
        Mock Test-PendingReboot {return $false}
        Mock Invoke-Reboot
        Mock DISM {"State : Enabled"}
        
        Chocolatey Install "somefeature" -source "WindowsFeatures" | out-null

        it "will not Call Chocolatey" {
            Assert-MockCalled Call-Chocolatey -times 0
        }
    }   

    Context "When WindowsFeature is not already installed" {
        Mock Test-PendingReboot {return $false}
        Mock Invoke-Reboot
        
        Chocolatey Install "somefeature" -source "WindowsFeatures" | out-null

        it "will Call Chocolatey" {
            Assert-MockCalled Call-Chocolatey
        }
    }

    Context "When a reboot was triggered" {
        Mock Call-Chocolatey { $Boxstarter.IsRebooting=$true }
        Mock Test-PendingReboot {$false}
        $boxstarter.RebootOk=$true
        Mock Invoke-Reboot
        Mock Remove-Item
        Mock Get-ChildItem {@("dir1","dir2")} -parameterFilter {$path -match "\\lib\\pkg.*"}

        Chocolatey Install pkg | out-null

        it "will delete package folder" {
            Assert-MockCalled Remove-Item -parameterFilter {$path -eq "dir2"}
        }
    }

    Context "When chocolatey returns an erroneous exit code" {
        Mock Test-PendingReboot {return $false}
        Mock Invoke-Reboot
        Mock Call-Chocolatey {$global:LASTEXITCODE=1}
        
        $error = Chocolatey Install pkg 2>&1

        it "will write an error" {
            $error| should match "Chocolatey reported an unsuccessful exit code of 1"
        }
    }

    #Not sure why I need to do this but pester test drive cleanup
    #does not properly cleanup without it
    #Remove-Item $TestDrive -recurse -force
}