function Write-BoxstarterLogo {
    $boxMod=(IEX (Get-Content (Join-Path $Boxstarter.Basedir Boxstarter.Common\Boxstarter.Common.psd1) | Out-String))
    Write-BoxstarterMessage "Boxstarter Version $($boxMod.ModuleVersion)" -nologo -Color White
    Write-BoxstarterMessage "$($boxMod.Copyright) https://boxstarter.org`r`n" -nologo -Color White
}
