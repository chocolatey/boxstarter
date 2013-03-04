try { 
    $boxstarterPath=Join-Path $env:AppData Boxstarter
    $tools = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
    $ModuleName = (Get-ChiltItem $tools).BaseName

    if(!(test-Path $boxstarterPath)){
        mkdir $boxstarterPath
    }
    if(test-Path (Join-Path $boxstarterPath $ModuleName)){
        Remove-Item (Join-Path $boxstarterPath $ModuleName) -Recurse -Force
    }
    Copy-Item "$tools\*" $boxstarterPath -Recurse -Force -Exclude ChocolateyInstall.ps1

    if($env:PSModulePath){
        $modules=($env:PSModulePath -split ';' | ?{ !($_.ToLower() -match "\\boxstarter$")}) -join ';'
        $modules+=$boxstarterPath
    } else {
        $modules=$boxstarterPath
    }
    if(!$env:PSModulePath -or !($env:PSModulePath -contains $boxstarterPath)){
        [Environment]::SetEnvironmentVariable('PSModulePath', $modules, 'User')
        $env:PSModulePath = $modules
    }

    $successMsg = @"
A Boxstarter Module has been added to your Module path. Use 'Get-Module Boxstarter.*' to list all Boxstarter Modules.
Use 'Get-Command -Module Boxstarter.*' to list all available Boxstarter Commands.
Use 'Get-Help Boxstarter' or visit http://Boxstarter.Codeplex.com for more Info
"@

    Write-ChocolateySuccess $successMsg
} catch {
    Write-ChocolateyFailure $ModuleName "$($_.Exception.Message)"
    throw 
}