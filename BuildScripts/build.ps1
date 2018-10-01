param (
    [string]$Action="default",
    [switch]$Help,
    [string]$VmName,
    [string]$package,
    [string]$testName
)
$here = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
    Invoke-Expression ((new-object net.webclient).DownloadString("https://bit.ly/psChocInstall"))
}

if(!(Test-Path $env:ChocolateyInstall\lib\Psake*)) { cinst psake -y --no-progress }
if(!(Test-Path $env:ChocolateyInstall\lib\7zip.CommandLine*)) { cinst 7zip.CommandLine -y --no-progress }
if(!(Test-Path $env:ChocolateyInstall\lib\pester*)) { cinst pester -y --no-progress }
if(!(Test-Path $env:ChocolateyInstall\lib\AzurePowershell*)) { cinst AzurePowershell -y --no-progress }
if(!(Test-Path $env:ChocolateyInstall\lib\WindowsAzureLibsForNet*)) { cinst WindowsAzureLibsForNet --version 2.5 -y --no-progress }
if(!(Test-Path $env:ChocolateyInstall\bin\nuget.exe)) { cinst nuget.commandline -y --no-progress }
if(!(Test-Path $env:ChocolateyInstall\bin\ReportUnit.exe)) { choco install reportunit -y --source https://nuget.org/api/v2 --no-progress }

if($Help){
  try {
    Write-Host "Available build tasks:"
    psake -nologo -docs | Out-Host -paging
  } catch {}
  return
}

$psakeDir = (Get-ChildItem $env:ChocolateyInstall\lib\Psake*)
if($psakeDir.length -gt 0) {$psakeDir = $psakeDir[-1]}
."$psakeDir\tools\psake\psake.ps1" "$here/default.ps1" $Action -ScriptPath $psakeDir\tools\psake -parameters $PSBoundParameters

if($psake.build_success -eq $false) {
  exit 1;
}
else {
  exit 0;
}
