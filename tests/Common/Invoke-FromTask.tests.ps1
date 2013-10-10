$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Invoke-FromTask" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
        % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true
    $mycreds = New-Object System.Management.Automation.PSCredential ("$env:username", (New-Object System.Security.SecureString))

    Context "When Invoking Task Normally"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue

        Invoke-FromTask "new-Item $env:temp\test.txt -value 'this is a test' -type file | Out-Null" -Credential $mycreds -Timeout 0

        It "Should invoke the command"{
            Get-Content $env:temp\test.txt | should be "this is a test"
        }
    }

    Context "When Invoking Task with output"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue

        $result=Invoke-FromTask "Write-Output 'here is some output'" -Credential $mycreds -Timeout 0

        It "Should invoke the command"{
            $result | should be "here is some output"
        }
    }

    Context "When Invoking Task with bad credentials"{
        $myBadcreds = New-Object System.Management.Automation.PSCredential ("poo", (New-Object System.Security.SecureString))

        try {Invoke-FromTask "return" -Credential $myBadcreds -Timeout 0 2>&1 | Out-Null} catch {$err=$_}

        It "Should invoke the command"{
            $err.Exception | should match "Unable to create scheduled task as"
        }
    }

    Context "When Invoking Task that takes 3 seconds"{
        Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue

        Invoke-FromTask "Start-Sleep -seconds 3;new-Item $env:temp\test.txt -value 'this is a test' -type file | Out-Null;start-sleep -seconds 1" -Credential $mycreds -Timeout 0

        It "Should block until finished"{
            "$env:temp\test.txt" | should Exist
        }
    }

    Context "When Invoking Task that is idle longer than timeout"{
        try { Invoke-FromTask "Start-Process calc.exe -Wait" -Credential $mycreds -Timeout 2} catch {$err=$_}
        $id=Get-WmiObject -Class Win32_Process -Filter "Name='calc.exe'" | select ProcessId | % { $_.ProcessId }
        KILL $id

        It "Should timeout"{
            $err.Exception | should match "likely in a hung state"
        }
    }
}