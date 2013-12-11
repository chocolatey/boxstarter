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

    ## Create a task that will run with full network privileges.
    ## In this task, we call Enable-PsRemoting
    schtasks /CREATE /TN 'Enable Remoting' /SC WEEKLY /RL HIGHEST ``
        /RU $username /RP $password ``
        /TR "powershell -noprofile -command Enable-PsRemoting -Force" /F |
        Out-String
    schtasks /RUN /TN 'Enable Remoting' | Out-String

    `$securePass = ConvertTo-SecureString $password -AsPlainText -Force
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

    Write-Verbose "Configuring $computername"
    $command = "powershell -NoProfile -EncodedCommand $encoded"
    $null = Invoke-WmiMethod -Computer $computername -Credential $credential `
        Win32_Process Create -Args $command
    Sleep 10
    Write-Verbose "Testing connection"
    for($count = 1; $count -le 10; $count++) {
        $wmiResult = Invoke-Command $computername {
            Get-WmiObject Win32_ComputerSystem } -Credential $credential -ErrorAction SilentlyContinue
        if($wmiResult -ne $Null){
            Write-BoxstarterMessage "PowerShell Remoting enabled successfully"
            break
        }
        $global:Error.RemoveAt(0)
    }
}
