function Install-Boxstarter($here, $ModuleName) {
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
    Import-Module "$boxstarterPath\Boxstarter.Common" -DisableNameChecking
    write-host "Boxstarter is now ready. You can type 'Boxstarter' from any command line at any path."
    $successMsg = @"
The $ModuleName Module has been copied to $boxstarterPath and added to your Module path. 
You will need to open a new console for the path to be visible.
Use 'Get-Module Boxstarter.* -ListAvailable' to list all Boxstarter Modules.
To list all available Boxstarter Commands, use:
PS:>Import-Module $ModuleName
PS:>Get-Command -Module Boxstarter.*

To find more info visit http://Boxstarter.Codeplex.com or use:
PS:>Import-Module $ModuleName
PS:>Get-Help Boxstarter
"@
    Write-BoxstarterMessage $successMsg
}


function PersistBoxStarterPathToEnvironmentVariable($variableName){
    $value = [Environment]::GetEnvironmentVariable($variableName, 'User')
    if($value){
        $values=($value -split ';' | ?{ !($_.ToLower() -match "\\boxstarter$")}) -join ';'
        $values+=";$boxstarterPath"
    } 
    elseif($variableName -eq "PSModulePath") {
        $values=[environment]::getfolderpath("mydocuments")
        $values +="\WindowsPowerShell\Modules;$boxstarterPath"
    }
    else {
        $values ="$boxstarterPath"
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