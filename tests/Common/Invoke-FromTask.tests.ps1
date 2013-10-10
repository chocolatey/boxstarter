$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Invoke-FromTask" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
        % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true
    Remove-Item $env:temp\test.txt -ErrorAction SilentlyContinue
    $mycreds = New-Object System.Management.Automation.PSCredential ("$env:username", (New-Object System.Security.SecureString))

    Context "When Invoking Task Normally"{
        Invoke-FromTask "new-Item $env:temp\test.txt -value 'this is a test' -type file | Out-Null" -Credential $mycreds -Timeout 0

        It "Should invoke the command"{
            Get-Content $env:temp\test.txt | should be "this is a test"
        }
    }
}