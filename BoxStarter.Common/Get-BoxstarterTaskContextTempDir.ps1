
function Get-BoxstarterTaskContextTempDir {
    $sysTemp = [System.Environment]::GetEnvironmentVariable('TEMP','Machine')
    $stableTempDir = Join-Path $sysTemp "BoxstarterTemp"
    if (-Not (Test-Path $stableTempDir)) {
        try {
            New-Item -ItemType Directory -Path $stableTempDir -Force | Out-Null
        } 
        catch {
            Write-BoxstarterMessage "failed to create $stableTempDir"
            throw
        }
    }
    $stableTempDir
}
