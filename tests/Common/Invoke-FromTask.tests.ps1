$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()

schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
        /RU "$($identity.Name)" /IT `
/TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
        Out-Null

Describe "Invoke-FromTask" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
        % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true
    $mycreds = New-Object System.Management.Automation.PSCredential ("$env:username", (New-Object System.Security.SecureString))

    Context "When Invoking Task Normally"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue

        Invoke-FromTask "new-Item $env:temp\test.txt -value `"this is a test from `$PWD`" -type file | Out-Null" -Credential $mycreds -IdleTimeout 0

        It "Should invoke the command"{
            Get-Content $env:temp\test.txt | should be "this is a test from $PWD"
        }
        It "Should delete the task"{
            schtasks /query /TN 'Ad-Hoc Task' 2>&1 | out-null
            $LastExitCode | should be 1
        }
    }

    Context "When Invoking a task with output"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue
        Mock write-host {
            $script:out += $object
            Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
        }

        Invoke-FromTask "Write-Output 'here is some output'" -IdleTimeout 0 -verbose
        It "Should invoke the command"{
            $script:out | should be "here is some output`r`n"
        }
    }

    Context "When Invoking a task with an error"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue

        try{Invoke-FromTask "Throw 'This is an error'" -Credential $mycreds -IdleTimeout 0 2>&1 | Out-Null} catch { $err=$_}

        It "Should throw the error"{
            $err.Exception | should match "This is an error"
        }
        It "Should delete the task"{
            schtasks /query /TN 'Ad-Hoc Task' 2>&1 | out-null
            $LastExitCode | should be 1
        }
    }

    Context "When Invoking Task that takes 3 seconds"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue

        Invoke-FromTask "Start-Sleep -seconds 3;new-Item $env:temp\test.txt -value 'this is a test' -type file | Out-Null;start-sleep -seconds 1" -Credential $mycreds -IdleTimeout 0

        It "Should block until finished"{
            "$env:temp\test.txt" | should Exist
        }
    }

    Context "When Invoking Task that is idle longer than idle timeout"{
        try { Invoke-FromTask "Start-Process journal.exe -Wait" -Credential $mycreds -IdleTimeout 2} catch {$err=$_}
        $origId=Get-WmiObject -Class Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%-EncodedCommand%'" | select ProcessId | % { $_.ProcessId }
        $id=Get-WmiObject -Class Win32_Process -Filter "Name='journal.exe'" | select ProcessId | % { $_.ProcessId }
        start-sleep -seconds 2

        It "Should timeout"{
            $err.Exception | should match "likely in a hung state"
        }
        It "Should delete the task"{
            schtasks /query /TN 'Ad-Hoc Task' 2>&1 | out-null
            $LastExitCode | should be 1
        }
        It "Should kill the original powershell task"{
            $origId | should be $null
        }
    }

    Context "When Invoking Task that is not idle but lasts longer than total timeout"{
        try { Invoke-FromTask "start-sleep -seconds 30" -Credential $mycreds -TotalTimeout 2} catch {$err=$_}
        $origId=Get-WmiObject -Class Win32_Process -Filter "name = 'powershell.exe' and CommandLine like '%-EncodedCommand%'" | select ProcessId | % { $_.ProcessId }

        It "Should timeout"{
            $err.Exception | should match "likely in a hung state"
        }
        It "Should delete the task"{
            schtasks /query /TN 'Ad-Hoc Task' 2>&1 | out-null
            $LastExitCode | should be 1
        }
        It "Should kill the original powershell task"{
            $origId | should be $null
        }
    }
}

schtasks /DELETE /TN 'Boxstarter Task' /F 2>&1 | Out-null