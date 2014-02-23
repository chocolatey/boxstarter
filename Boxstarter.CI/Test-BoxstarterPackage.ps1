function Test-BoxstarterPackage($PackageName) {
    $options = Get-BoxstarterDeployOptions
    Invoke-BoxstarterBuild $PackageName
    if(!$options.DeploymentTargetCredentials){
        throw "No DeploymentTargetCredentials has been sent. Use Set-BoxstarterBuildOptions to set DeploymentTargetCredentials"
    }
    $global:pester = @{arr_testTags=""}
    $global:testName = ""
    if($options.DeploymentVMProvider -and $options.DeploymentVMProvider -gt 0){
        $vmArgs=@{}
        if($options.DeploymentCloudServiceName){$vmArgs.CloudServiceName=$options.DeploymentCloudServiceName}
        if($options.RestoreCheckpoint){$vmArgs.CheckpointName=$options.RestoreCheckpoint}
        $vmArgs.Provider=$options.DeploymentVMProvider
    }
    $PackageName | % {
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
