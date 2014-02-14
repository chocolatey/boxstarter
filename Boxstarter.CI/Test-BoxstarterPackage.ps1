function Test-BoxstarterPackage($package) {
    $options = Get-BoxstarterDeployOptions
    Invoke-BoxstarterBuild $package
    if(!$options.DeploymentTargetCredentials){
        throw "No DeploymentTargetCredentials has been sent. Use Set-BoxstarterBuildOptions to set DeploymentTargetCredentials"
    }
    $global:pester = @{arr_testTags=""}
    $global:testName = ""
    $vmArgs=@{}
    if($options.DeploymentCloudServiceName){$vmArgs.CloudServiceName=$options.DeploymentCloudServiceName}
    if($options.RestoreCheckpoint){$vmArgs.CheckpointName=$options.RestoreCheckpoint}
    $package | % {
        $p=$_
        Describe "Testing Package $p" {
            $options.DeploymentTargetNames | 
              Enable-BoxstarterVM -Provider $options.DeploymentVMProvider -Credential $options.DeploymentTargetCredentials @vmArgs -verbose | 
                Install-BoxstarterPackage -PackageName $p -Force -verbose | % {
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
