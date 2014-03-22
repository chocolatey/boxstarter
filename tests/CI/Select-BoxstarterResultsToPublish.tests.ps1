$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.CI){Remove-Module boxstarter.CI}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.CI\*.ps1 | 
    ? { $_.Path -like "*-*" } | 
    % { . $_.ProviderPath }

Describe "Select-BoxstarterResultsToPublish" {
    $Boxstarter.SuppressLogging=$true

    Context "When all results for a package pass" {
        $pkgName="package1"
        $results = (new-Object PSObject -Property @{
            Package=$pkgName 
            TestComputerName="c1"
            Status="PASSED"
        }), (new-Object PSObject -Property @{
            Package=$pkgName 
            TestComputerName="c1"
            Status="PASSED"
        })

        $result = $results | Select-BoxstarterResultsToPublish

        it "Should return the name of the package" {
            $result | should be $pkgName 
        }
    }
}