param (
    [string]$Action="default",
    [string]$ChocoPath,
    [switch]$Help
)
$here = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
if($ChocoPath){
    $ChocoPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ChocoPath)
    Write-Output "Setting ChocolateyInstall to $ChocoPath"
    [Environment]::SetEnvironmentVariable("ChocolateyInstall", $ChocoPath, [System.EnvironmentVariableTarget]::User)
    $env:ChocolateyInstall=$ChocoPath
}
if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
    iex ((new-object net.webclient).DownloadString("http://bit.ly/psChocInstall"))
}

cinstm psake
cinstm 7zip.CommandLine
cinstm pester

if($Help){ 
  try {
    Write-Host "Available build tasks:"
    psake -nologo -docs | Out-Host -paging
  } catch {}
  return
}

$psakeDir = (dir $env:ChocolateyInstall\lib\Psake*)
if($psakeDir.length -gt 0) {$psakerDir = $psakeDir[-1]}
."$psakeDir\tools\psake.ps1" "$here/default.ps1" $Action -ScriptPath $psakeDir\tools