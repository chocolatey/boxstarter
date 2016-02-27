$tools = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. (Join-Path $tools Setup.ps1)
try { 
    $ModuleName = (Get-ChildItem $tools | ?{ $_.PSIsContainer }).BaseName
    $preInstall = Join-Path $tools "$modulename.preinstall.ps1"
    if(Test-Path $preInstall) { .$preInstall }
    Install-Boxstarter $tools $ModuleName $env:chocolateyPackageParameters
} catch {
    write-output $_ | fl * -force
    throw $_.Exception
}