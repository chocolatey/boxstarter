param (
    [string]$Action="default",
    [switch]$Help
)
$here = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
    iex ((new-object net.webclient).DownloadString("http://bit.ly/psChocInstall"))
}

cinstm psake

if($Help){ 
  try {
    Get-Help "$($MyInvocation.MyCommand.Definition)" -full | Out-Host -paging
    Write-Host "Available build tasks:"
    psake -nologo -docs | Out-Host -paging
  } catch {}
  return
}

psake "$here/default.ps1" $Action