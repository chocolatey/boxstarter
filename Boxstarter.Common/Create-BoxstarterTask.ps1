function Create-BoxstarterTask{
<#
.SYNOPSIS
Creates a Scheduled Task for Boxstarter operations that require a local
administrative token

.DESCRIPTION
Create-BoxstarterTask creates a scheduled task.  This task is present
throughout a boxstarter installation process and is used when Boxstarter
needs to complete a task that cannot use a remote token. This function
does not run the task. It simply creates it.

.Parameter Credential
The credentials under which the task will run.

.LINK
https://boxstarter.org
Invoke-FromTask
Remove-BoxstarterTask

#>
    param([Management.Automation.PsCredential]$Credential)
    Remove-BoxstarterError {
        if($Credential.GetNetworkCredential().Password.length -gt 0){
            schtasks /CREATE /TN 'Temp Boxstarter Task' /SC WEEKLY /RL HIGHEST `
                /RU "$($Credential.UserName)" /IT /RP $Credential.GetNetworkCredential().Password `
            /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F | Out-Null

            #Give task a normal priority
            $taskFile = Join-Path $env:TEMP RemotingTask.txt
            Remove-Item $taskFile -Force -ErrorAction SilentlyContinue
            [xml]$xml = schtasks /QUERY /TN 'Temp Boxstarter Task' /XML
            if($xml.Task.Settings.Priority -eq $null) {
                $priority = $xml.CreateElement("Priority", "http://schemas.microsoft.com/windows/2004/02/mit/task")
                $xml.Task.Settings.AppendChild($priority)
            }
            $xml.Task.Settings.Priority="4"
            $xml.Save($taskFile)
            schtasks /CREATE /TN 'Boxstarter Task' /RU "$($Credential.UserName)" /IT /RP $Credential.GetNetworkCredential().Password /XML "$taskFile" /F | Out-Null
            schtasks /DELETE /TN 'Temp Boxstarter Task' /F | Out-Null
        }
        elseif(!((schtasks /QUERY /TN 'Boxstarter Task' /FO LIST 2>&1) -contains 'Logon Mode:    Interactive/Background')) { #For testing
            schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
                    /RU "$($Credential.UserName)" /IT `
            /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
                    Out-Null
        }
    }
    if($LastExitCode -gt 0){
        throw "Unable to create scheduled task as $($Credential.UserName)"
    }
}
