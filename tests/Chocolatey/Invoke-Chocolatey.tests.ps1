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


# When you change the ChocolateyWrapper type you'll get this error for a
# subsequent test run:
# > Cannot add type. The type name 'Boxstarter.ChocolateyWrapper' already exists.
# You'll have to kill the testrunner to solve this.
# Package Manager Console: 
#   Get-Process -Name vstest.executionengine.x86 | Stop-Process
Describe "Invoke-Chocolatey" {
	$global:choco = $null

	Context "adds chocolatey wrapper types" {
		Mock Write-BoxstarterMessage
		Mock Enter-BoxstarterLogable

		Invoke-Chocolatey -chocoArgs "--version"

		it "has message written" {
			Assert-MockCalled Write-BoxstarterMessage -ParameterFilter { $message -eq "Types added..." }
		}
	}

	Context "invokes created type" {
		Invoke-Chocolatey -chocoArgs "--version"
	}

	Context "subsequent calls" {
		$global:choco = $null
		Invoke-Chocolatey -chocoArgs "--version"

		$global:choco = $null
		Invoke-Chocolatey -chocoArgs "--version"
	}

	Context "logger" {
		# Just invoke to make sure the types are created and loaded.
		Invoke-Chocolatey -chocoArgs "--version"

		$logfile = Join-Path $env:TEMP "test.log"
		$log = New-Object -TypeName boxstarter.PsLogger -ArgumentList `
			$true,`
			$logfile,`
			$false

		$log.Debug("output {0}", "debug")
		$log.Debug({ "debug" });
		$log.Info("output {0}", "info")
		$log.Info({ "info" });
		$log.Warn("output {0}", "warn")
		$log.Warn({ "warn" });
		$log.Error("output {0}", "error")
		$log.Error({ "error" });
		$log.Fatal("output {0}", "fatal")
		$log.Fatal({ "fatal" });

		it "has written to file" {
			Test-Path -Path $logfile | Should Be $true
		}
	}
}

Describe "PsLogger" {
	# Just invoke to make sure the types are created and loaded.
	Invoke-Chocolatey -chocoArgs "--version"

	Add-Type @"
namespace Boxstarter.Tests
{
	using System;
	using System.IO;

	public class RedirectConsole
	{
		public string Execute(Action a)
		{
			using (var writer = new StringWriter())
            {
                Console.SetOut(writer);
				a();

                return writer.ToString();
            }
		}
	}
}
"@
	$redirect = New-Object Boxstarter.Tests.RedirectConsole
	$logfile = Join-Path $env:TEMP "test.log"

	Context "logDebug is false" {
		$log = New-Object -TypeName boxstarter.PsLogger -ArgumentList `
			$false,`
			$logfile,`
			$false

		It "should hide VERBOSE info" {
			$redirect.Execute({ $log.Info("VERBOSE: {0}", "info") }) | Should Be ""
		}

		It "should print normal info" {
			$redirect.Execute({ $log.Info("Hello: {0}", "info") }) | Should BeLike "Hello: info*"
		}
	}

	
	Context "logDebug is true" {
		$log = New-Object -TypeName boxstarter.PsLogger -ArgumentList `
			$true,`
			$logfile,`
			$false

		It "should print VERBOSE info" {
			$redirect.Execute({ $log.Info("VERBOSE: {0}", "info") }) | Should BeLike "VERBOSE: info*"
		}

		It "should print normal info" {
			$redirect.Execute({ $log.Info("Hello: {0}", "info") }) | Should BeLike "Hello: info*"
		}
	}
}