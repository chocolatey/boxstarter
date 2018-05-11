function Enable-RemotePsRemoting {
##############################################################################
##
## Enable-RemotePsRemoting
##
## From Windows PowerShell Cookbook (O'Reilly)
## by Lee Holmes (http://www.leeholmes.com/guide)
##
##############################################################################

<#

.SYNOPSIS

Enables PowerShell Remoting on a remote computer. Requires that the machine
responds to WMI requests, and that its operating system is Windows Vista or
later.

.EXAMPLE

Enable-RemotePsRemoting <Computer>

#>

param(
    ## The computer on which to enable remoting
    $Computername,

    ## The credential to use when connecting
    [Management.Automation.PsCredential]$Credential
)

    $credential = Get-Credential $credential
    $username = $credential.Username
    $password = $credential.GetNetworkCredential().Password

    $script = @"

    `$log = Join-Path `$env:TEMP Enable-RemotePsRemoting.output.txt
    Remove-Item -Force `$log -ErrorAction SilentlyContinue
    Start-Transcript -Path `$log

    if(!(1,3,4,5 -contains (Get-WmiObject win32_computersystem).DomainRole)) {
        `$networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'{DCB00C01-570F-4A9B-8D69-199FDBA5723B}'))
        `$connections = `$networkListManager.GetNetworkConnections()

        `$connections | % {`$_.GetNetwork().SetCategory(1)}
    }

    ## Create a task that will run with full network privileges.
    ## In this task, we call Enable-PsRemoting
    schtasks /CREATE /TN 'Temp Enable Remoting' /SC WEEKLY /RL HIGHEST ``
        /RU $username /RP "$password" ``
        /TR "powershell -noprofile -command Enable-PsRemoting -Force | Out-File (Join-Path `$env:TEMP Enable-PSRemoting.txt)" /F |
        Out-String

    ##Give task a normal priority
    `$taskFile = Join-Path `$env:TEMP RemotingTask.txt
    [xml]`$xml = schtasks /QUERY /TN 'Temp Enable Remoting' /XML
    `$xml.Task.Settings.Priority="4"
    `$xml.Save(`$taskFile)
    schtasks /CREATE /TN 'Enable Remoting' /RU $username /RP "$password" /XML "`$taskFile" /F | Out-String
    schtasks /DELETE /TN 'Temp Enable Remoting' /F | Out-String

    schtasks /RUN /TN 'Enable Remoting' | Out-String

    `$securePass = ConvertTo-SecureString "$password" -AsPlainText -Force
    `$credential =
        New-Object Management.Automation.PsCredential $username,`$securepass

    ## Wait for the remoting changes to come into effect
    for(`$count = 1; `$count -le 10; `$count++)
    {
        `$output = Invoke-Command localhost { 1 } -Cred `$credential ``
            -ErrorAction SilentlyContinue
        if(`$output -eq 1) { break; }

        "Attempt `$count : Not ready yet."
        Sleep 5
    }

    ## Delete the temporary task
    schtasks /DELETE /TN 'Enable Remoting' /F | Out-String
    Stop-Transcript

"@

    $commandBytes = [System.Text.Encoding]::Unicode.GetBytes($script)
    $encoded = [Convert]::ToBase64String($commandBytes)

    Write-BoxstarterMessage "Configuring $computername" -Verbose
    $command = "powershell -NoProfile -EncodedCommand $encoded"
    $null = Invoke-WmiMethod -Computer $computername -Credential $credential `
        Win32_Process Create -Args $command
    Sleep 10
    Write-BoxstarterMessage "Testing connection" -Verbose
    for($count = 1; $count -le 100; $count++) {
        $wmiResult = Invoke-Command $computername {
            Get-WmiObject Win32_ComputerSystem } -Credential $credential -ErrorAction SilentlyContinue
        if($wmiResult -ne $Null){
            Write-BoxstarterMessage "PowerShell Remoting enabled successfully"
            break
        }
        else {
            Write-BoxstarterMessage "Attempt $count failed." -Verbose
        }
        if($global:Error.Count -gt 0){
            Write-BoxstarterMessage "$($global:Error[0])" -Verbose
            $global:Error.RemoveAt(0)
        }
    }
}
