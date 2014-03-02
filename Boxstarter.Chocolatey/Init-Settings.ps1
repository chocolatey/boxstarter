$config = Get-BoxstarterConfig
if(!$BoxStarter.LocalRepo){
    $BoxStarter.LocalRepo=$config.LocalRepo
}
$Boxstarter.NugetSources=$config.NugetSources
$Boxstarter.RebootOk=$true
