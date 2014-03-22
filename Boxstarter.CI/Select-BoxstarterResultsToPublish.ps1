function Select-BoxstarterResultsToPublish {
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
            if($_.Status -eq "passed"){
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