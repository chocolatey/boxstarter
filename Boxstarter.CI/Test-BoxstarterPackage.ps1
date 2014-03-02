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
        $currentColor = $Host.UI.RawUI.ForegroundColor
        $summaryColor = "Green"
        try {
            Get-BoxstarterPackages | % {
                $Host.UI.RawUI.ForegroundColor = $currentColor
                $pkg = $_
                $summary.Total++
                if(Test-PackageVersionGreaterThanPublished $pkg) {
                    Invoke-BuildAndTest $pkg.Id $options $vmArgs $summary | % {
                        if($_.Status="PASSED") {
                            $summary.Passed++
                            $Host.UI.RawUI.ForegroundColor = "Green"
                        }
                        else {
                            $summary.Failed++
                            $Host.UI.RawUI.ForegroundColor = "Red"
                            $summaryColor= "Red"
                        }
                        Write-Result $pkg $_
                    }
                }
                else {
                    $summary.Skipped++
                    Write-Result $pkg
                }
            } | Format-Table -Property @{Name="Status";Expression={$_.Status};Width=9},`
                                       @{Name="Package";Expression={$_.Package};Width=15},`
                                       @{Name="Computer";Expression={$_.Computer};Width=15},`
                                       @{Name="Repo Version";Expression={$_.RepoVersion};Width=16},`
                                       @{Name="Published Version";Expression={$_.PublishedVersion};Width=16}
        }
        finally{
            $Host.UI.RawUI.ForegroundColor = $currentColor
        }

        Write-BoxstarterMessage "Total: $($summary.Total) Passed: $($summary.Passed) Failed: $($summary.Failed) Skipped: $($summary.Skipped)" -Color $summaryColor
    }
}

function Write-Result($package, $result) {
    $res = New-Object PSObject -Property @{
        Package=$package.Id
        RepoVersion=$package.Version
        PublishedVersion=$(if($package.PublishedVersion -eq $null) {"Not Published"} else { $package.PublishedVersion })
        Computer=$result.TestComputerName
        ResultDetails=$(if($result -eq $null) {@{}} else { $result.ResultDetails })
        Status=$(if($result -eq $null) {"SKIPPED"} else { $result.Status })
    }
    $res | Out-BoxstarterLog -quiet
    return $res
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
    $origLogSetting=$Boxstarter.SuppressLogging
    $Boxstarter.SuppressLogging=$true
    $progressId=5000 #must be a unique int. This is likely not to conflict with anyone else
    try {
        Write-Progress -id $progressId "Building $packageName."
        Invoke-BoxstarterBuild $packageName -Quiet

        $options.DeploymentTargetNames | % {
            Write-Progress -Id $progressId -Activity "Testing $packageName" -Status "on Machine: $_"
            if($vmArgs) {
                Enable-BoxstarterVM -Credential $options.DeploymentTargetCredentials -VMName $_  @vmArgs 
            }
            else {
                $_
            }
        } | 
        Install-BoxstarterPackage -credential $options.DeploymentTargetCredentials -PackageName $packageName -Force | % {
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
    }finally { $Boxstarter.SuppressLogging = $origLogSetting }
}

function Test-InstallSuccess ($testResult) {
    if($testResult.Completed -and $testResult.Errors.Count -eq 0) {
        return $true
    }
}