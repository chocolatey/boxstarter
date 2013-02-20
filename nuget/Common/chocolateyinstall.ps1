try { 
    if($env:PSModulePath){
        $modules=$env:PSModulePath -split ';'
        $userPath=($modules -like '*\WindowsPowerShell\Modules')[0]

    }
    $boxstarterDir = (Split-Path -parent $MyInvocation.MyCommand.Definition)
    $path = Join-Path $boxstarterDir  'boxstarter.bat'
    Write-Host "Adding $packageBatchFileName and pointing to $path"
    "@echo off
    ""$path"" %*" | Out-File $packageBatchFileName -encoding ASCII 

    write-host "Boxstarter is now ready. You can type 'Boxstarter' from any command line at any path. "

    Write-ChocolateySuccess 'Boxstarter'
} catch {
    Write-ChocolateyFailure 'Boxstarter' "$($_.Exception.Message)"
    throw 
}