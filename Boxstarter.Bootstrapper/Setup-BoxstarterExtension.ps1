
function Setup-BoxstarterExtension {
    $extensionBaseDir = "$env:ChocolateyInstall\extensions\boxstarter-choco"
    New-Item -ItemType Directory -Path $extensionBaseDir -Force | Out-Null

    @"
if (`$env:BoxstarterChocoExtension) {
Write-Host "Lets.GetBoxstarter() :-)"        
Import-Module '$($boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1' -DisableNameChecking -ArgumentList `$true
Write-Host "Boxstarter superpowers initiated..."
}
"@ | Out-File "$extensionBaseDir/boxstarter-choco.psm1" -Encoding utf8

    Import-Module "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1" -DisableNameChecking:$true
    . "$env:ChocolateyInstall/helpers/functions/Write-FunctionCallLogMessage.ps1"
    . "$env:ChocolateyInstall/helpers/functions/Test-ProcessAdminRights.ps1"
    . "$env:ChocolateyInstall/helpers/functions/Set-EnvironmentVariable.ps1"
    . "$env:ChocolateyInstall/helpers/functions/Install-ChocolateyEnvironmentVariable.ps1"
    $installEnvVarParam = @{
        variableName  = 'BoxstarterChocoExtension'
        variableValue = 'absolutely'
        variableType  = [System.EnvironmentVariableTarget]::Machine
    }
    Install-ChocolateyEnvironmentVariable @installEnvVarParam
}
