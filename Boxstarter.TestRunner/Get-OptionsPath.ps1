function Get-OptionsPath {
    $boxstarterScriptPath = Join-Path $Boxstarter.LocalRepo "BoxstarterScripts"
    if(!(Test-Path $boxstarterScriptPath)) {
        mkdir $boxstarterScriptPath | Out-Null
    }
    return Join-Path $boxstarterScriptPath Options.xml
}
