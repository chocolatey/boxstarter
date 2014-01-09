try { 
    Write-ChocolateySuccess "Boxstarter"
    Write-Host "To load all Boxstarter Modules immediately, just enter 'BoxstarterShell'." -ForegroundColor Yellow
} catch {
    Write-ChocolateyFailure "Boxstarter" "$($_.Exception.Message)"
    throw 
}