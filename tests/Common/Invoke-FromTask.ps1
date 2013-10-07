$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Invoke-FromTask" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
        % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true

    Context "When Invoking Task Normally"{
        Invoke-FromTask "new-Item $env:temp\test.txt -value 'this is a test' -type file" $mycreds

        It "Should invoke the command"{

        }
    }
}