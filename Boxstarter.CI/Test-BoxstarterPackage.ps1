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
        $packageName = Get-BoxstarterPackages | ? {
            Test-PackageVersionGreaterThanPublished $_
        } | % {$_.Name}
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
    if(!$package.Feed) { return $false }

    if(!$package.PublishedVersion) { return $true }

    $pkgVersion=New-Object -TypeName Version -ArgumentList (Remove-PreRelease $package.Version)
    $pubVersion=New-Object -TypeName Version -ArgumentList (Remove-PreRelease $package.PublishedVersion)

    if($pkgVersion -gt $pubVersion) {
        return $true 
    }
    else {
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