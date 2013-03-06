function Install-Boxstarter($here) {
    $boxstarterPath=Join-Path $env:AppData Boxstarter
    if(!(test-Path $boxstarterPath)){
        mkdir $boxstarterPath
    }
    $packagePath=Join-Path $boxstarterPath BuildPackages
    if(!(test-Path $packagePath)){
        mkdir $packagePath
    }    
    foreach($ModulePath in (Get-ChildItem $here | ?{ $_.PSIsContainer })){
        $target=Join-Path $boxstarterPath $modulePath.BaseName
        if(test-Path $target){
            Remove-Item $target -Recurse -Force
        }
    }
    Copy-Item "$here\*" $boxstarterPath -Recurse -Force -Exclude ChocolateyInstall.ps1, Setup.*

    PersistBoxStarterPathToEnvironmentVariable "PSModulePath"
    PersistBoxStarterPathToEnvironmentVariable "Path"
    write-host "Boxstarter is now ready. You can type 'Boxstarter' from any command line at any path."

    $successMsg = @"
A Boxstarter Module has been added to your Module path. Use 'Get-Module Boxstarter.* -ListAvailable' to list all Boxstarter Modules.
To list all available Boxstarter Commands, use:
PS:>Import-Module Boxstarter.*
PS:>Get-Command -Module Boxstarter.*

To find more info visit http://Boxstarter.Codeplex.com or use:
PS:>Import-Module Boxstarter.*
PS:>Get-Help Boxstarter
"@
    Write-Host $successMsg
}


function PersistBoxStarterPathToEnvironmentVariable($variableName){
    $value = [Environment]::GetEnvironmentVariable($variableName, 'User')
    if($value){
        $values=($value -split ';' | ?{ !($_.ToLower() -match "\\boxstarter$")}) -join ';'
        $values+=";$boxstarterPath"
    } else {
        $values=$boxstarterPath
    }
    if(!$value -or !($values -contains $boxstarterPath)){
        $values = $values.Replace(';;',';')
        [Environment]::SetEnvironmentVariable($variableName, $values, 'User')
        $varValue = Get-Content env:\$variableName
        $varValue += ";$boxstarterPath"
        $varValue = $varValue.Replace(';;',';')
        Set-Content env:\$variableName -value $varValue
    }
}