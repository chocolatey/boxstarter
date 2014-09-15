function Select-BoxstarterResultsToPublish {
<#
.SYNOPSIS
Returns successful Boxstarter packages from provided test results 
eligible to be published to a nuget feed.

.DESCRIPTION
Test-BoxstarterPackage will return a set of test results given an 
array of packages or an entire repository. Select-BoxstarterResultsToPublish
can consume these results and return the package IDs of the packages who 
had all test machines pass the package install. One could then have
Publish-BoxstarterPackage consume this output and publish those packages 
to their respectful feeds.

.PARAMETER Results
An array of PSObjects returned from Test-BostarterPackages. These 
objects contain metadata about a packages' test run on a single test 
machine. The data will report if the test completed and if there were 
any exceptions.

.EXAMPLE
Test-BoxstarterPackages | Select-BoxstarterResultsToPublish | Publish-BoxstarterPackage

This will test all packages in the Boxstarter LocalRepo that have a 
repository version greater than its published version. The results of
the tests will be passed to Select-BoxstarterResultsToPublish to 
choose the packages which passed on all test machines. 
Set-BoxstarterDeployOptions can be used to designate the machines to 
be used for testing. The successful packages are then piped to 
Publish-BoxstarterPackage which publishes the packages to their 
associated nuget feed.

.LINK
http://boxstarter.org
Test-BoxstarterPackage
Publish-BoxstarterPackage
Set-BoxstarterDeployOptions
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True)]
        [PSObject[]]$Results
    )
    Begin {
        $succesfullPackages = @()
        $failedPackages = @()
    }
    Process {
        $Results | % {
            if($_.Status -eq "failed"){
                $failedPackages += $_.Package
            }
            if($_.Status -eq "passed" -and ($succesfullPackages -notcontains $_.Package)){
                $succesfullPackages += $_.Package
            }
        }
    }
    End {
        $succesfullPackages | ? {
            $failedPackages -notcontains  $_
        } | % {
            $_
        }
    }
}