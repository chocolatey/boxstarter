function Remove-BoxstarterTask {
<#
.SYNOPSIS
Deletes the Boxstarter task.

.DESCRIPTION
Deletes the Boxstarter task. Boxstarter calls this when an 
installation session completes.

.LINK
http://boxstarter.org
Create-BoxstarterTask
Invoke-BoxstarterTask

#>    
    Write-BoxstarterMessage "Removing Boxstarter Scheduled Task..." -Verbose
	$currentErrorCount = $Global:Error.Count
    $result = schtasks /DELETE /TN 'Boxstarter Task' /F 2>&1
    Write-BoxstarterMessage "Removed Boxstarter Scheduled Task with this result: $result" -Verbose

    if($Global:Error.Count -gt $currentErrorCount){
        $limit = $Global:Error.Count - $currentErrorCount
        for($i=0;$i -lt $limit;$i++) {
            $Global:Error.RemoveAt(0)
        }
    }
}