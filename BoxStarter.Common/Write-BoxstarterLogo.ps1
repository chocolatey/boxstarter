function Write-BoxstarterLogo {
    $boxMod=(IEX (Get-Content (join-path $Boxstarter.Basedir Boxstarter.Common\Boxstarter.Common.psd1) | Out-String))
    write-BoxstarterMessage "Boxstarter Version $($boxMod.ModuleVersion)" -nologo -Color White
    write-BoxstarterMessage "$($boxMod.Copyright) http://boxstarter.org`r`n" -nologo -Color White
}