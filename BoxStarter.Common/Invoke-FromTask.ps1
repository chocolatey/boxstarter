function Invoke-FromTask {
<#
.SYNOPSIS
Invokes a command inside of a scheduled task

.DESCRIPTION
This invokes the boxstarter scheduled task.
The task is run in an elevated session using the provided
credentials. If the processes started by the task become idle for
more that the specified timeout, the task will be terminated. All
output and any errors from the task will be streamed to the calling
session.

 .PARAMETER Command
 The command to run in the task.

.PARAMETER IdleTimeout
The number of seconds after which the task will be terminated if it
becomes idle. The value 0 is an indefinite timeout and 120 is the
default.

.PARAMETER TotalTimeout
The number of seconds after which the task will be terminated whether
it is idle or active.

.EXAMPLE
Invoke-FromTask Install-WindowsUpdate -AcceptEula

This will install Windows Updates in a scheduled task

.EXAMPLE
Invoke-FromTask "DISM /Online /NoRestart /Enable-Feature:TelnetClient" -IdleTimeout 20

This will use DISM.exe to install the telnet client and will kill
the task if it becomes idle for more that 20 seconds.

.LINK
https://boxstarter.org
Create-BoxstarterTask
Remove-BoxstarterTask
#>
    param(
        $command,
        $DotNetVersion = $null,
        $idleTimeout=120,
        $totalTimeout=3600
    )
    Write-BoxstarterMessage "Invoking $command in scheduled task" -Verbose
    $runningCommand = Add-TaskFiles $command $DotNetVersion

    $taskProc = start-Task $runningCommand

    if($taskProc -ne $null){
        Write-BoxstarterMessage "Command launched in process $taskProc" -Verbose
        try {
            $waitProc=Get-Process -id $taskProc -ErrorAction Stop
            Write-BoxstarterMessage "Waiting on $($waitProc.Id)" -Verbose
        } catch { $global:error.RemoveAt(0) }
    }

    try {
        Wait-ForTask $waitProc $idleTimeout $totalTimeout
    }
    catch {
        Write-BoxstarterMessage "error thrown managing task" -verbose
        Write-BoxstarterMessage "$($_ | fl * -force | Out-String)" -verbose
        throw $_
    }
    Write-BoxstarterMessage "Task has completed" -Verbose

    $verboseStream = Get-CliXmlStream (Get-ErrorFileName) 'verbose'
    if($verboseStream -ne $null) {
        Write-BoxstarterMessage "Warnings and Verbose output from task:"
        $verboseStream | % { Write-Host $_ }
    }

    $errorStream = Get-CliXmlStream (Get-ErrorFileName) 'error'
    if($errorStream -ne $null -and $errorStream.length -gt 0) {
        throw $errorStream
    }
}

function Get-ErrorFileName { "$env:temp\BoxstarterError.stream" }

function Get-CliXmlStream($cliXmlFile, $stream) {
    $content = Get-Content $cliXmlFile
    if($content.count -lt 2) { return $null }

    # Strip the first line containing '#< CLIXML'
    [xml]$xml = $content[1..($content.count-1)]

    # return stream stripping carriage retuens and linefeeds
    $xml.DocumentElement.ChildNodes |
      ? { $_.S -eq $stream } |
      % { $_.'#text'.Replace('_x000D_','').Replace('_x000A_','') } |
      Out-String
}

function Get-ChildProcessMemoryUsage {
    param(
        $ID=$PID,
        [int]$res=0
    )
    Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" | % {
        if($_.ProcessID -ne $null) {
            try {
                $proc = Get-Process -ID $_.ProcessID -ErrorAction Stop
                Write-BoxstarterMessage "$($_.Name) $($proc.PrivateMemorySize + $proc.WorkingSet)" -Verbose
                $res += $proc.PrivateMemorySize + $proc.WorkingSet
                $res += (Get-ChildProcessMemoryUsage $_.ProcessID $res)
            } catch { $global:error.RemoveAt(0) }
        }
    }
    $res
}

function Add-TaskFiles($command, $DotNetVersion) {
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("`$ProgressPreference='SilentlyContinue';$command"))
    $fileContent=@"
$(if($DotNetVersion -ne $null){"`$env:COMPLUS_version='$DotNetVersion'"})
Start-Process powershell -NoNewWindow -Wait -RedirectStandardError $(Get-ErrorFileName) -RedirectStandardOutput $env:temp\BoxstarterOutput.stream -WorkingDirectory '$PWD' -ArgumentList "-noprofile -ExecutionPolicy Bypass -EncodedCommand $encoded"
Remove-Item $env:temp\BoxstarterTask.ps1 -ErrorAction SilentlyContinue
"@
    Set-Content $env:temp\BoxstarterTask.ps1 -value $fileContent -force
    New-Item $env:temp\BoxstarterOutput.stream -Type File -Force | Out-Null
    New-Item (Get-ErrorFileName) -Type File -Force | Out-Null
    $encoded
}

function start-Task($encoded){
    $tasks=@()
    $tasks+=gwmi Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%$encoded%'" | select ProcessId | % { $_.ProcessId }
    Write-BoxstarterMessage "Found $($tasks.Length) tasks already running" -Verbose
    $taskResult = schtasks /RUN /I /TN 'Boxstarter Task'
    if($LastExitCode -gt 0){
        throw "Unable to run scheduled task. Message from task was $taskResult"
    }
    Write-BoxstarterMessage "Launched task. Waiting for task to launch command..." -Verbose
    do{
        if(!(Test-Path $env:temp\BoxstarterTask.ps1)){
            Write-BoxstarterMessage "Task Completed before its process was captured." -Verbose
            break
        }
        $taskProc=gwmi Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%$encoded%'" | select ProcessId | % { $_.ProcessId } | ? { !($tasks -contains $_) }

        Start-Sleep -Second 1
    }
    Until($taskProc -ne $null)

    return $taskProc
}

function Test-TaskTimeout($waitProc, $idleTimeout) {
    if($memUsageStack -eq $null){
        $script:memUsageStack=New-Object -TypeName System.Collections.Stack
    }
    if($idleTimeout -gt 0){
        $lastMemUsageCount=Get-ChildProcessMemoryUsage $waitProc.ID
        Write-BoxstarterMessage "Memory read: $lastMemUsageCount" -Verbose
        Write-BoxstarterMessage "Memory count: $($memUsageStack.Count)" -Verbose
        $memUsageStack.Push($lastMemUsageCount)
        if($lastMemUsageCount -eq 0 -or (($memUsageStack.ToArray() | ? { $_ -ne $lastMemUsageCount }) -ne $null)){
            $memUsageStack.Clear()
        }
        if($memUsageStack.Count -gt $idleTimeout){
            Write-BoxstarterMessage "Task has exceeded its timeout with no activity. Killing task..."
            KillTree $waitProc.ID
            throw "TASK:`r`n$command`r`n`r`nIs likely in a hung state."
        }
    }
    Start-Sleep -Second 1
}

function Wait-ForTask($waitProc, $idleTimeout, $totalTimeout){
    $reader=New-Object -TypeName System.IO.FileStream -ArgumentList @(
        "$env:temp\BoxstarterOutput.Stream",
        [system.io.filemode]::Open,[System.io.FileAccess]::ReadWrite,
        [System.IO.FileShare]::ReadWrite)
    try{
        $procStartTime = $waitProc.StartTime
        while($waitProc -ne $null -and !($waitProc.HasExited)) {
            $timeTaken = [DateTime]::Now.Subtract($procStartTime)
            if($totalTimeout -gt 0 -and $timeTaken.TotalSeconds -gt $totalTimeout){
                Write-BoxstarterMessage "Task has exceeded its total timeout. Killing task..."
                KillTree $waitProc.ID
                throw "TASK:`r`n$command`r`n`r`nIs likely in a hung state."
            }

            $byte = New-Object Byte[] 100
            $count=$reader.Read($byte,0,100)
            if($count -ne 0){
                $text = [System.Text.Encoding]::Default.GetString($byte,0,$count)
                $text | Write-Host -NoNewline
            }
            else {
                Test-TaskTimeout $waitProc $idleTimeout
            }
        }
        Start-Sleep -Second 1
        Write-BoxstarterMessage "Proc has exited: $($waitProc.HasExited) or Is Null: $($waitProc -eq $null)" -Verbose
        $byte=$reader.ReadByte()
        $text=$null
        while($byte -ne -1){
            $text += [System.Text.Encoding]::Default.GetString($byte)
            $byte=$reader.ReadByte()
        }
        if($text -ne $null){
            $text | Write-Host -NoNewline
        }
    }
    finally{
        $reader.Dispose()
        if($waitProc -ne $null -and !$waitProc.HasExited){
            KillTree $waitProc.ID
        }
    }
}

function KillTree($id){
    Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" | % {
        if($_.ProcessID -ne $null) {
            Invoke-SilentKill $_.ProcessID
            Write-BoxstarterMessage "Killing $($_.Name)" -Verbose
            KillTree $_.ProcessID
        }
    }
    Invoke-SilentKill $id -wait
}

function Invoke-SilentKill($id, [switch]$wait) {
    try {
        $p = Kill $id -ErrorAction Stop -Force
        if($wait) {
            while($p -ne $null -and !$p.HasExited){
                Start-Sleep 1
            }
        }
    }
    catch {
        $global:error.RemoveAt(0)
    }
}
