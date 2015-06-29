$config = Get-BoxstarterConfig
if(!$BoxStarter.LocalRepo){
   $BoxStarter.LocalRepo=$config.LocalRepo
}
if($BoxStarter.LocalRepo.StartsWith("$env:windir")) {
   $BoxStarter.LocalRepo = Join-Path $(Get-BoxstarterTempDir) "BuildPackages"
   if(!(Test-Path $BoxStarter.LocalRepo)) { mkdir $BoxStarter.LocalRepo | Out-Null }
}
$Boxstarter.NugetSources=$config.NugetSources
$Boxstarter.RebootOk=$true
$Boxstarter.VendoredChocoPath = Join-Path $Boxstarter.BaseDir "Chocolatey"