param (
    [string]$Action="default",
    [switch]$Help,
    [string]$VmName,
    [string]$package,
    [string]$testName
)
$here = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
    iex ((new-object net.webclient).DownloadString("http://bit.ly/psChocInstall"))
}

if(!(Test-Path $env:ChocolateyInstall\lib\Psake*)) { cinst psake -y }
if(!(Test-Path $env:ChocolateyInstall\lib\7zip.CommandLine*)) { cinst 7zip.CommandLine -y }
if(!(Test-Path $env:ChocolateyInstall\lib\pester*)) { cinst pester -v 3.3.11 -y }
if(!(Test-Path $env:ChocolateyInstall\lib\WindowsAzurePowershell*)) { cinst WindowsAzurePowershell -y }
if(!(Test-Path $env:ChocolateyInstall\lib\WindowsAzureLibsForNet*)) { cinst WindowsAzureLibsForNet -y }
if(!(Test-Path $env:ChocolateyInstall\bin\nuget.exe)) { cinst nuget.commandline -y }

if($Help){ 
  try {
    Write-Host "Available build tasks:"
    psake -nologo -docs | Out-Host -paging
  } catch {}
  return
}

$psakeDir = (dir $env:ChocolateyInstall\lib\Psake*)
if($psakeDir.length -gt 0) {$psakerDir = $psakeDir[-1]}
."$psakeDir\tools\psake.ps1" "$here/default.ps1" $Action -ScriptPath $psakeDir\tools -parameters $PSBoundParameters