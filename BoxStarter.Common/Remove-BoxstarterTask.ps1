function Remove-BoxstarterTask {
<#
.SYNOPSIS
Deletes the boxstarter task.

.DESCRIPTION
Deletes the boxstarter task. Boxstarter calls this when an 
installation session completes.

.LINK
http://boxstarter.codeplex.com
Create-BoxstarterTask
Invoke-BoxstarterTask

#>    
    Write-BoxstarterMessage "Removing Boxstarter Scheduled Task..." -Verbose
	$result = schtasks /DELETE /TN 'Boxstarter Task' /F 2>&1
    Write-BoxstarterMessage "Removed Boxstarter Scheduled Task with this result: $result" -Verbose

}