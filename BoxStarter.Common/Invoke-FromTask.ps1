function Invoke-FromTask ($command, $Credential, $timeout=120){
    Write-BoxstarterMessage "Invoking $command in scheduled task"
    Add-TaskFiles $command

    Create-Task $Credential

    $taskProc = start-Task

    if($taskProc -ne $null){
        write-debug "Command launched in process $taskProc"
        $waitProc=get-process -id $taskProc -ErrorAction SilentlyContinue
        Write-Debug "Waiting on $($waitProc.Id)"
        $memUsageStack = New-Object -TypeName System.Collections.Stack
    }

    Wait-ForTask $waitProc
    
    try{$errorStream=Import-CLIXML $env:temp\BoxstarterError.stream} catch {}
    if($errorStream -ne $null){
        throw $errorStream
    }
}

function Get-ChildProcessMemoryUsage {
    param($ID=$PID)
    [int]$res=0
    Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" | out-null
    % { if($_.ProcessID -ne $null) {$res += $_.WorkingSetSize;Write-Debug "$($_.Name) $($_.WorkingSetSize)"}}
    Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" |
      % { if($_.ProcessID -ne $null) {$res += Get-ChildProcessMemoryUsage $_.ProcessID;Write-Debug "$($_.Name) $($_.WorkingSetSize)"}}
    $res
}

function Add-TaskFiles($command) {
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("$command"))
    $fileContent=@"
Start-Process powershell -Wait -RedirectStandardError $env:temp\BoxstarterError.stream -RedirectStandardOutput $env:temp\BoxstarterOutput.stream -ArgumentList "-noprofile -ExecutionPolicy Bypass -EncodedCommand $encoded"
Remove-Item $env:temp\BoxstarterTask.ps1 -ErrorAction SilentlyContinue
"@
    Set-Content $env:temp\BoxstarterTask.ps1 -value $fileContent -force
    new-Item $env:temp\BoxstarterOutput.stream -Type File -Force | out-null
    new-Item $env:temp\BoxstarterError.stream -Type File -Force | out-null
}

function Create-Task($Credential){
        $pass=$credential.GetNetworkCredential().Password
    if($pass.length -gt 0){
        schtasks /CREATE /TN 'Ad-Hoc Task' /SC WEEKLY /RL HIGHEST `
            /RU $credential.Username /RP $pass `
            /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
            Out-Null
    }
    else { #For testing
        schtasks /CREATE /TN 'Ad-Hoc Task' /SC WEEKLY /RL HIGHEST `
                /RU $credential.Username /IT `
                /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
                Out-Null
    }
    if($LastExitCode -gt 0){
        throw "Unable to create scheduled task as $($credential.Username)"
    }
}

function start-Task{
    $tasks=@()
    $tasks+=gwmi Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%-EncodedCommand%'" | select ProcessId | % { $_.ProcessId }
    Write-Debug "Found $($tasks.Length) tasks already running"
    schtasks /RUN /I /TN 'Ad-Hoc Task' | Out-Null
    if($LastExitCode -gt 0){
        throw "Unable to run scheduled task"
    }
    write-debug "Launched task. Waiting for task to launch comand..."
    do{
        if(!(Test-Path $env:temp\BoxstarterTask.ps1)){
            Write-Debug "Task Completed before its process was captured."
            break
        }
        $taskProc=gwmi Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%-EncodedCommand%'" | select ProcessId | % { $_.ProcessId } | ? { !($tasks -contains $_) }

        Start-Sleep -Second 1
    }
    Until($taskProc -ne $null)

    return $taskProc
}

function Test-TaskTimeout($waitProc) {
    if($timeout -gt 0){
        $lastMemUsageCount=Get-ChildProcessMemoryUsage $waitProc.ID
        Write-Debug "Memory read: $lastMemUsageCount"
        $memUsageStack.Push($lastMemUsageCount)
        if($lastMemUsageCount -eq 0 -or (($memUsageStack.ToArray() | ? { $_ -ne $lastMemUsageCount }) -ne $null)){
            $memUsageStack.Clear()
        }
        if($memUsageStack.Count -gt $timeout){
            Write-BoxstarterMessage "Task has exceeded its timeout with no activity. Killing task..."
            Write-Debug "Timed out"
            $waitProc.Kill()
            throw "TASK:`r`n$command`r`n`r`nIs likely in a hung state."
        }
    }
    Start-Sleep -Second 1
}

function Wait-ForTask($waitProc){
    $reader=New-Object -TypeName System.IO.FileStream -ArgumentList @(
        "$env:temp\BoxstarterOutput.Stream",
        [system.io.filemode]::Open,[System.io.FileAccess]::ReadWrite,
        [System.IO.FileShare]::ReadWrite)
    try{
        while($waitProc -ne $null -and !($waitProc.HasExited)) {
            $byte = New-Object Byte[] 100
            $count=$reader.Read($byte,0,100)
            if($count -ne 0){
                [System.Text.Encoding]::Default.GetString($byte,0,$count) | write-host -NoNewline
            }
            else {
                Test-TaskTimeout $waitProc
            }
        }
        Start-Sleep -Second 1
        Write-Debug "Proc has exited: $($waitProc.HasExited) or Is Null: $($waitProc -eq $null)"
        $byte=$reader.ReadByte()
        while($byte -ne -1){
            [System.Text.Encoding]::Default.GetString($byte) | write-host -NoNewline
            $byte=$reader.ReadByte()
        }
    }
    finally{
        if($waitProc -ne $null -and !$waitProc.HasExited){
            $waitProc.Kill()
        }
        $reader.Dispose()
        schtasks /DELETE /TN 'Ad-Hoc Task' /F | Out-null
    }    
}