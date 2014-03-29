function Get-FeedsAPIKeyPath {
    $boxstarterScriptPath = join-Path $Boxstarter.LocalRepo "BoxstarterScripts"
    if(!(Test-Path $boxstarterScriptPath)) {
        mkdir $boxstarterScriptPath | Out-Null
    }
    return Join-Path $boxstarterScriptPath FeedAPIKeys.xml
}