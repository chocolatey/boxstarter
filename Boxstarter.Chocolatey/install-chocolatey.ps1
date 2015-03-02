function Install-Chocolatey($pkgUrl) {
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
  Write-Host "Installing chocolatey on this machine"
  $toolsFolder = Join-Path $tempDir "tools"
  $chocInstallPS1 = Join-Path $toolsFolder "chocolateyInstall.ps1"

  & $chocInstallPS1

  write-host 'Ensuring chocolatey commands are on the path'
  $chocInstallVariableName = "ChocolateyInstall"
  $chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName, [System.EnvironmentVariableTarget]::User)
  $chocoExePath = 'C:\ProgramData\Chocolatey\bin'
  if ($chocoPath -ne $null) {
    $chocoExePath = Join-Path $chocoPath 'bin'
  }

  if ($($env:Path).ToLower().Contains($($chocoExePath).ToLower()) -eq $false) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path',[System.EnvironmentVariableTarget]::Machine)
  }
}
