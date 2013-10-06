function Invoke-FromTask ($command){
    Write-BoxstarterMessage "Invoking $command in scheduled task"
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("$command"))
    $fileContent=@"
Start-Process powershell -RedirectStandardError $env:temp\BoxstarterError.stream -RedirectStandardOutput $env:temp\BoxstarterOutput.stream -ArgumentList "-noprofile -ExecutionPolicy Bypass -EncodedCommand $encoded"
"@
    Set-Content $env:temp\BoxstarterTask.ps1 -value $fileContent -force
    $decryptedPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ChocolateyPassword)
    )

    schtasks /CREATE /TN 'Ad-Hoc Task' /SC WEEKLY /RL HIGHEST `
        /RU "$env:userdomain\$($Boxstarter.BoxstarterUser)" /RP $decryptedPass `
        /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
        Out-String
    if($LastExitCode -gt 0){
        throw "Unable to create scheduled task as $env:userdomain\$($Boxstarter.BoxstarterUser)"
    }

    $tasks=@()
    $tasks+=gwmi Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%-EncodedCommand%'" | select ProcessId | % { $_.ProcessId }
    
    new-Item $env:temp\BoxstarterOutput.stream -Type File -Force
    new-Item $env:temp\BoxstarterError.stream -Type File -Force
    schtasks /RUN /TN 'Ad-Hoc Task' | Out-String
    if($LastExitCode -gt 0){
        throw "Unable to run scheduled task"
    }
    do{
        $taskProc=gwmi Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%-EncodedCommand%'" | select ProcessId | % { $_.ProcessId } | ? { !($tasks -contains $_) }
        Start-Sleep -Second 1
    }
    Until($taskProc -ne $null)

    write-host "found task process"
    $waitProc=get-process -id $taskProc -ErrorAction SilentlyContinue
    $memUsageStack = New-Object -TypeName System.Collections.Stack
    $reader=New-Object -TypeName System.IO.FileStream -ArgumentList @("$env:temp\BoxstarterOutput.Stream",[system.io.filemode]::Open,[System.io.FileAccess]::ReadWrite,[System.IO.FileShare]::ReadWrite)
    try{
        while($waitProc -ne $null -and !($waitProc.HasExited)) {
            $byte = New-Object Byte[] 100
            $count=$reader.Read($byte,0,100)
            if($count -ne 0){
                [System.Text.Encoding]::Default.GetString($byte,0,$count) | write-host -NoNewline
            }
            else {
                $lastMemUsageCount=Get-ChildProcessMemoryUsage $waitProc.ID
                #write-host "mem:$lastMemUsageCount"
                #write-host $memUsageStack.Count
                $memUsageStack.Push($lastMemUsageCount)
                if($lastMemUsageCount -eq 0 -or (($memUsageStack.ToArray() | ? { $_ -ne $lastMemUsageCount }) -ne $null)){
                    $memUsageStack.Clear()
                }
                if($memUsageStack.Count -gt 120){
                    $waitProc.Kill()
                    throw "TASK:`r`n$command`r`n`r`nIs likely in a hung state."
                }
                Start-Sleep -Second 1
            }
        }
        write-host "task completed"
        Start-Sleep -Second 1
        $byte=$reader.ReadByte()
        while($byte -ne -1){
            [System.Text.Encoding]::Default.GetString($byte) | write-host -NoNewline
            $byte=$reader.ReadByte()
        }
    }
    finally{
        if(!$waitProc.HasExited){$waitProc.Kill()}
        $reader.Dispose()
        schtasks /DELETE /TN 'Ad-Hoc Task' /F | Out-String
    }
    
    try{$errorStream=Import-CLIXML $env:temp\BoxstarterError.stream} catch {}
    if($errorStream -ne $null){
        throw $errorStream
    }
}

function Get-ChildProcessMemoryUsage {
    param($ID=$PID)
    [int]$res=0
    Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" | out-null
    % { if($_.ProcessID -ne $null) {$res += $_.WorkingSetSize}}
    Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$ID" |
      % { if($_.ProcessID -ne $null) {$res += Get-ChildProcessMemoryUsage $_.ProcessID}}
    $res
}