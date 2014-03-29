function Get-SecretOptionsPath {
    $boxstarterScriptPath = join-Path $Boxstarter.LocalRepo "BoxstarterScripts"
    if(!(Test-Path $boxstarterScriptPath)) {
        mkdir $boxstarterScriptPath | Out-Null
    }
    return Join-Path $boxstarterScriptPath $env:ComputerName-$env:username-Options.xml
}