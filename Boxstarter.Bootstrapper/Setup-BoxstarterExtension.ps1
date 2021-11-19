
function Setup-BoxstarterExtension {
    $extensionBaseDir = "$env:ChocolateyInstall\extensions\boxstarter-choco"
    New-Item -ItemType Directory -Path $extensionBaseDir -Force | Out-Null

    @"
Write-Host "Lets.GetBoxstarter() :-)"        
Import-Module '$($boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1' -DisableNameChecking -ArgumentList `$true
"@ | Out-File "$extensionBaseDir/boxstarter-choco.psm1" -Encoding utf8

}
