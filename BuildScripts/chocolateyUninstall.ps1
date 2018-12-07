$tools = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. (Join-Path -Path $tools -ChildPath 'Setup.ps1')

try {
    $ModuleName = (Get-ChildItem $tools | Where-Object { $_.PSIsContainer }).BaseName
    Uninstall-Boxstarter $tools $ModuleName $env:chocolateyPackageParameters
}
catch {
    Write-Output $_ | Format-List * -force
    throw $_.Exception
}