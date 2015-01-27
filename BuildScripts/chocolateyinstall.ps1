$tools = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. (Join-Path $tools Setup.ps1)
try { 
    $ModuleName = (Get-ChildItem $tools | ?{ $_.PSIsContainer }).BaseName
    Install-Boxstarter "$(Split-Path -parent $MyInvocation.MyCommand.Definition)" $ModuleName $env:chocolateyPackageParameters
    Write-ChocolateySuccess $ModuleName
} catch {
    Write-ChocolateyFailure $ModuleName "$($_.Exception.Message)"
    throw 
}