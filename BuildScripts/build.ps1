param (
    [string]$Action="default",
    [switch]$Help,
    [string]$VmName,
    [string]$package,
    [string]$testName
)
$here = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
    iex ((new-object net.webclient).DownloadString("https://bit.ly/psChocInstall"))
}

if(!(Test-Path $env:ChocolateyInstall\lib\Psake*)) { cinst psake -y }
if(!(Test-Path $env:ChocolateyInstall\lib\7zip.CommandLine*)) { cinst 7zip.CommandLine -y }
if(!(Test-Path $env:ChocolateyInstall\lib\pester*)) { cinst pester -v 3.4.0 -y }
if(!(Test-Path $env:ChocolateyInstall\lib\AzurePowershell*)) { cinst AzurePowershell -y }
if(!(Test-Path $env:ChocolateyInstall\lib\WindowsAzureLibsForNet*)) { cinst WindowsAzureLibsForNet --version 2.5 -y }
if(!(Test-Path $env:ChocolateyInstall\bin\nuget.exe)) { cinst nuget.commandline -y }
if(!(Test-Path $env:ChocolateyInstall\bin\ReportUnit.exe)) { choco install reportunit -y --source https://nuget.org/api/v2 }

if($Help){
  try {
    Write-Host "Available build tasks:"
    psake -nologo -docs | Out-Host -paging
  } catch {}
  return
}

$psakeDir = (dir $env:ChocolateyInstall\lib\Psake*)
if($psakeDir.length -gt 0) {$psakerDir = $psakeDir[-1]}
."$psakeDir\tools\psake\psake.ps1" "$here/default.ps1" $Action -ScriptPath $psakeDir\tools\psake -parameters $PSBoundParameters

if($psake.build_success -eq $false) {
  exit 1;
}
else {
  exit 0;
}
