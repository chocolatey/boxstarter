try { 
    $boxstarterPath=Join-Path $env:AppData Boxstarter
    $tools = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
    $ModuleName = (Get-ChildItem $tools | ?{ $_.PSIsContainer }).BaseName

    if(!(test-Path $boxstarterPath)){
        mkdir $boxstarterPath
    }
    $modulePath=Join-Path $boxstarterPath $ModuleName
    if(test-Path $modulePath){
        Remove-Item $modulePath -Recurse -Force
    }
    Copy-Item "$tools\*" $boxstarterPath -Recurse -Force -Exclude ChocolateyInstall.ps1

    $modulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
    if($modulePath){
        $modules=($modulePath -split ';' | ?{ !($_.ToLower() -match "\\boxstarter$")}) -join ';'
        $modules+=";$boxstarterPath"
    } else {
        $modules=$boxstarterPath
    }
    if(!$modulePath -or !($modulePath -contains $boxstarterPath)){
        [Environment]::SetEnvironmentVariable('PSModulePath', $modules, 'User')
        $env:PSModulePath += ";$boxstarterPath"
    }

    if(test-Path (Join-Path $tools Boxstarter.bat)) {
        $packageBatchFileName = Join-Path $env:ChocolateyInstall "bin\boxstarter.bat"
        $path = Join-Path $boxstarterPath  'boxstarter.bat'
        Write-Host "Adding $packageBatchFileName and pointing to $path"
        "@echo off
        ""$path"" %*" | Out-File $packageBatchFileName -encoding ASCII 
        write-host "Boxstarter is now ready. You can type 'Boxstarter' from any command line at any path. "
    }

    $successMsg = @"
A Boxstarter Module has been added to your Module path. Use 'Get-Module Boxstarter.* -ListAvailable' to list all Boxstarter Modules.
Use 'Get-Command -Module Boxstarter.*' to list all available Boxstarter Commands.
Use 'Get-Help Boxstarter' or visit http://Boxstarter.Codeplex.com for more Info
"@
    Write-Host $successMsg
    Write-ChocolateySuccess $ModuleName
} catch {
    Write-ChocolateyFailure $ModuleName "$($_.Exception.Message)"
    throw 
}