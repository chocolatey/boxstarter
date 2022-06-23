$config = Get-BoxstarterConfig
if (!$Boxstarter.LocalRepo) {
    $Boxstarter.LocalRepo = $config.LocalRepo
}
if ($Boxstarter.LocalRepo.StartsWith("$env:windir")) {
    $Boxstarter.LocalRepo = Join-Path $(Get-BoxstarterTempDir) "BuildPackages"
    if (!(Test-Path $Boxstarter.LocalRepo)) { 
        New-Item -ItemType Directory -Path $Boxstarter.LocalRepo -Force | Out-Null 
    }
}
$Boxstarter.NugetSources = $config.NugetSources
