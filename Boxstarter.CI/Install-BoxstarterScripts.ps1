function Install-BoxstarterScripts {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$RepoRootPath
    )
    
    $scriptPath = Join-Path $RepoRootPath BoxstarterScripts
    Write-BoxstarterMessage "Copying Boxstarter CI scripts to $scriptPath"

    if(!(Test-Path $scriptPath)) { Mkdir $scriptPath | Out-Null }
    Copy-Item "$($Boxstarter.BaseDir)\Boxstarter.CI\bootstrap.ps1" $scriptPath -Force 
    Copy-Item "$($Boxstarter.BaseDir)\Boxstarter.CI\BoxstarterBuild.ps1" $scriptPath -Force 
    Copy-Item "$($Boxstarter.BaseDir)\Boxstarter.CI\boxstarter.proj" $scriptPath -Force 
    Set-Content "$scriptPath\.gitignore" -Value "*-options.xml" -Force 
}