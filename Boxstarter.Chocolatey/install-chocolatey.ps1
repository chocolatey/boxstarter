function Install-Chocolatey($pkgUrl) {
  try {
    $currentChocoInstall = $env:ChocolateyInstall
    $env:ChocolateyInstall = $Boxstarter.VendoredChocoPath
    $chocTempDir = Join-Path $env:TEMP "chocolatey"
    $tempDir = Join-Path $chocTempDir "chocInstall"
    if (![System.IO.Directory]::Exists($tempDir)) {[System.IO.Directory]::CreateDirectory($tempDir)}
    $file = Join-Path $tempDir "chocolatey.zip"

    # download the package
    Get-HttpToFile $pkgUrl $file

    # download 7zip
    Write-Host "Download 7Zip commandline tool"
    $7zaExe = Join-Path $tempDir '7za.exe'
    Get-HttpToFile 'https://chocolatey.org/7za.exe' "$7zaExe"

    # unzip the package
    Write-Host "Extracting $file to $tempDir..."
    Start-Process "$7zaExe" -ArgumentList "x -o`"$tempDir`" -y `"$file`"" -Wait -NoNewWindow

    # call chocolatey install
    Write-Output "Installing chocolatey on this machine"
    Write-Output "This is separate chocolatey install used only by Boxstarter"
    $toolsFolder = Join-Path $tempDir "tools"
    $chocInstallModule = Join-Path $toolsFolder "chocolateySetup.psm1"

    if ($currentChocoInstall -eq $null) {
      $currentChocoInstall = "$env:programdata\chocolatey"
    }

    $PSModuleAutoLoadingPreference = "All"
    $boxBinPath = Join-Path $Boxstarter.VendoredChocoPath 'bin'
    $chocoBinPath = Join-Path $currentChocoInstall 'bin'

    Import-Module $chocInstallModule
    Initialize-Chocolatey $Boxstarter.VendoredChocoPath
    Set-Content -Path (Join-Path $Boxstarter.VendoredChocoPath 'ChocolateyInstall/functions/boxstarter_patch.ps1') -value @"
`$nugetExePath = "$chocoBinPath"
`$nugetLibPath = "$(Join-Path $currentChocoInstall 'lib')"
`$badLibPath = "$(Join-Path $currentChocoInstall 'lib-bad')"
"@

    if(!(Test-Path $chocoBinPath)){
        New-Item -Path $chocoBinPath -ItemType Directory
    }

    $currentEnv = [Environment]::GetEnvironmentVariable('path', 'Machine')
    if($currentEnv.IndexOf($chocoBinPath) -eq -1) {
        $currentEnv = $currentEnv.replace($boxBinPath, "$chocoBinPath;$boxBinPath")
    }
    [Environment]::SetEnvironmentVariable("path", $currentEnv, 'Machine')
  }
  finally {
    $env:ChocolateyInstall = $currentChocoInstall
    [Environment]::SetEnvironmentVariable("ChocolateyInstall", $currentChocoInstall, 'Machine')
  }
}
