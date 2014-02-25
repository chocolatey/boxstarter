function Test-BoxstarterPackage {
    [CmdletBinding()]
    param(
        [string[]]$PackageName
    )
    $options = Get-BoxstarterDeployOptions
    if(!$options.DeploymentTargetCredentials){
        throw "No DeploymentTargetCredentials has been sent. Use Set-BoxstarterBuildOptions to set DeploymentTargetCredentials"
    }

    if($options.DeploymentVMProvider -and $options.DeploymentVMProvider -gt 0){
        $vmArgs=@{}
        if($options.DeploymentCloudServiceName){$vmArgs.CloudServiceName=$options.DeploymentCloudServiceName}
        if($options.RestoreCheckpoint){$vmArgs.CheckpointName=$options.RestoreCheckpoint}
        $vmArgs.Provider=$options.DeploymentVMProvider
    }

    $summary=@{
        Total=0
        Passed=0
        Skipped=0
        Failed=0
    }

    if($packageName) {
        $PackageName | % {
            $pkg = $_
            Invoke-BuildAndTest $pkg $options $vmArgs $summary  | % {
                $summary.Total++
                if($_.Status="PASSED") {
                    $summary.Passed++
                }
                else {
                    $summary.Failed++
                }
                New-Object PSObject -Property @{
                    Package=$pkg.Name
                    RepoVersion="---"
                    PublishedVersion="---"
                    TestComputerName=$_.TestComputerName
                    ResultDetails=$_.ResultDetails
                    Status=$_.Status
                }
            }
        }
    }
    else {
        Get-BoxstarterPackages | % {
            $pkg = $_
            if(Test-PackageVersionGreaterThanPublished $pkg) {
                Write-Progress "Installing $pkg.Name. This may take several minutes..."
                Invoke-BuildAndTest $pkg.Name $options $vmArgs $summary | % {
                    $summary.Total++
                    if($_.Status="PASSED") {
                        $summary.Passed++
                    }
                    else {
                        $summary.Failed++
                    }
                    New-Object PSObject -Property @{
                        Package=$pkg.Id
                        RepoVersion=$pkg.Version
                        PublishedVersion=$(if($pkg.PublishedVersion -eq $null) {"Not Published"} else { $pkg.PublishedVersion })
                        TestComputerName=$_.TestComputerName
                        ResultDetails=$_.ResultDetails
                        Status=$_.Status
                    }
                }
            }
            else {
                $summary.Total++
                $summary.Skipped++
                New-Object PSObject -Property @{
                    Package=$pkg.Id
                    RepoVersion=$pkg.Version
                    PublishedVersion=$(if($pkg.PublishedVersion -eq $null) {"Not Published"} else { $pkg.PublishedVersion })
                    TestComputerName=$null
                    ResultDetails=@{}
                    Status="SKIPPED"
                }
            }
        }
        Write-BoxstarterMessage "Total: $($summary.Total) Passed: $($summary.Passed) Failed: $($summary.Failed) Skipped: $($summary.Skipped)"
    }
}

function Test-PackageVersionGreaterThanPublished ($package) {
    if(!$package.Feed) { 
        Write-BoxstarterMessage "No feed has been assigned to $($package.Name). It will not be built and tested" -verbose
        return $false 
    }

    if(!$package.PublishedVersion) {
        Write-BoxstarterMessage "$($package.Name) has not yet been published. It will be built and tested" -verbose
        return $true 
    }

    $pkgVersion=New-Object -TypeName Version -ArgumentList (Remove-PreRelease $package.Version)
    $pubVersion=New-Object -TypeName Version -ArgumentList (Remove-PreRelease $package.PublishedVersion)

    if($pkgVersion -gt $pubVersion) {
        Write-BoxstarterMessage "The repository version '$($package.Version)' for $($package.Name) is greater than the published version '$($package.PublishedVersion)'. It will be built and tested" -verbose
        return $true 
    }
    else {
        Write-BoxstarterMessage "The repository version '$($package.Version)' for $($package.Name) is not greater than the published version '$($package.PublishedVersion)'. It will not be built and tested" -verbose
        return $false 
    }
}

function Remove-PreRelease ([string]$versionString) {
    $idx=$versionString.IndexOf("-")
    if($idx -gt -1) {
        return $versionString.Substring(0,$idx)
    }
    else {
        return $versionString 
    }
}

function Invoke-BuildAndTest($packageName, $options, $vmArgs) {
    Invoke-BoxstarterBuild $packageName
    $options.DeploymentTargetNames | % {
        if($vmArgs) {
            Enable-BoxstarterVM -Credential $options.DeploymentTargetCredentials -VMName $_  @vmArgs -verbose 
        }
        else {
            $_
        }
    } | 
        Install-BoxstarterPackage -credential $options.DeploymentTargetCredentials -PackageName $packageName -Force -verbose | % {
            if(Test-InstallSuccess $_) {
                $status="PASSED"
            }
            else {
                $status="FAILED"
            }
            new-Object PSObject -Property @{
                Package=$packageName 
                TestComputerName=$_.ComputerName
                ResultDetails=$_
                Status=$status
            }
        }
}

function Test-InstallSuccess ($testResult) {
    if($testResult.Completed -and $testResult.Errors.Count -eq 0) {
        return $true
    }
}