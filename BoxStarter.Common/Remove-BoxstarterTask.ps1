function Remove-BoxstarterTask {
<#
.SYNOPSIS
Deletes the Boxstarter task.

.DESCRIPTION
Deletes the Boxstarter task. Boxstarter calls this when an
installation session completes.

.LINK
https://boxstarter.org
Create-BoxstarterTask
Invoke-BoxstarterTask

#>
    Write-BoxstarterMessage "Removing Boxstarter Scheduled Task..." -Verbose

    Remove-BoxstarterError {
        $result = schtasks /DELETE /TN 'Boxstarter Task' /F 2>&1
        Write-BoxstarterMessage "Removed Boxstarter Scheduled Task with this result: $result" -Verbose
    }
}
