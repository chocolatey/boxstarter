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

    #Hacks to get Pester to work with dynamicly created tests
    $global:pester = @{arr_testTags=""}
    $global:testName = ""

    if(!$packageName){
        Write-BoxstarterMessage "Searching for packages that need to be built and tested..."
        $packageName = Get-BoxstarterPackages | ? {
            Test-PackageVersionGreaterThanPublished $_
        } | % {$_.Name}
    }
    
    if($PackageName.Count -eq 0) {
        Write-BoxstarterMessage "All packages are up to date. Nothing to build and test."
        return
    }

    $PackageName | % {
        Invoke-BoxstarterBuild $_
        $p=$_
        Describe "Testing Package $p" {
            $options.DeploymentTargetNames | % {
                if($vmArgs) {
                    Enable-BoxstarterVM -Credential $options.DeploymentTargetCredentials -VMName $_  @vmArgs -verbose 
                }
                else {
                    $_
                }
            } | 
                Install-BoxstarterPackage -credential $options.DeploymentTargetCredentials -PackageName $p -Force -verbose | % {
                    $global:box_result = $_
                    It "Should Complete Install on Computer: $($box_result.ComputerName)" {
                        $box_result.Completed | Should be $true
                    }
                    It "Should have no exceptions on Computer: $($box_result.ComputerName)" {
                        $box_result.Errors.Count | should be 0
                    }
                }
        }
    }
}

function Test-PackageVersionGreaterThanPublished ($package) {
    if(!$package.Feed) { 
        Write-BoxstarterMessage "No feed has been assigned to $($package.Name). It will not be build and tested"
        return $false 
    }

    if(!$package.PublishedVersion) {
        Write-BoxstarterMessage "$($package.Name) has not yet been published. It will be built and tested"
        return $true 
    }

    $pkgVersion=New-Object -TypeName Version -ArgumentList (Remove-PreRelease $package.Version)
    $pubVersion=New-Object -TypeName Version -ArgumentList (Remove-PreRelease $package.PublishedVersion)

    if($pkgVersion -gt $pubVersion) {
        Write-BoxstarterMessage "The repository version '$($package.Version)' for $($package.Name) is greater than the published version '$($package.PublishedVersion)'. It will be built and tested"
        return $true 
    }
    else {
        Write-BoxstarterMessage "The repository version '$($package.Version)' for $($package.Name) is not greater than the published version '$($package.PublishedVersion)'. It will not be built and tested"
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