try { 
    Write-ChocolateySuccess "Boxstarter"
    Write-Host "To load all Boxstarter Modules immediately, just enter 'BoxstarterShell'." -ForegroundColor Yellow
    Write-Host "Interested in Windows Azure VM integration? Run CINST Boxstarter.Azure to install Boxstarter's Azure integration."
} catch {
    Write-ChocolateyFailure "Boxstarter" "$($_.Exception.Message)"
    throw 
}