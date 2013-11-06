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
http://boxstarter.codeplex.com
Invoke-FromTask
Remove-BoxstarterTask

#>
    param([Management.Automation.PsCredential]$Credential)
    if($BoxstarterPassword.length -gt 0){
        schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
            /RU "$($Credential.UserName)"  /IT /RP $Credential.GetNetworkCredential().Password `
        /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
            Out-Null
    }
    else { #For testing
        schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
                /RU "$($Credential.UserName)" /IT `
        /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
                Out-Null
    }
    if($LastExitCode -gt 0){
        throw "Unable to create scheduled task as $($Credential.UserName)"
    }
}