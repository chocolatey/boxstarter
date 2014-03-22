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
        $passPkgName="package1"
        $partialPkgName="package2"
        $failPkgName="package3"
        $passPkg2Name="package4"
        $results = (new-Object PSObject -Property @{
            Package=$passPkgName 
            TestComputerName="c1"
            Status="PASSED"
        }), (new-Object PSObject -Property @{
            Package=$passPkgName 
            TestComputerName="c2"
            Status="PASSED"
        }), (new-Object PSObject -Property @{
            Package=$partialPkgName 
            TestComputerName="c1"
            Status="FAILED"
        }), (new-Object PSObject -Property @{
            Package=$partialPkgName 
            TestComputerName="c2"
            Status="PASSED"
        }), (new-Object PSObject -Property @{
            Package=$failPkgName 
            TestComputerName="c1"
            Status="FAILED"
        }), (new-Object PSObject -Property @{
            Package=$failPkgName 
            TestComputerName="c2"
            Status="FAILED"
        }), (new-Object PSObject -Property @{
            Package=$passPkg2Name 
            TestComputerName="c1"
            Status="PASSED"
        }), (new-Object PSObject -Property @{
            Package=$passPkg2Name 
            TestComputerName="c2"
            Status="PASSED"
        })

        $result = $results | Select-BoxstarterResultsToPublish

        it "Should only return 2 packages" {
            $result.Count | should be 2 
        }
        it "Should return the first packages that passed both computers" {
            $result[0] | should be $passPkgName 
        }
        it "Should return the second packages that passed both computers" {
            $result[1] | should be $passPkg2Name 
        }
    }
}