$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Remove-BoxstarterTask" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 |
        % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true

    Context "When Removing a Task that does not exist"{

        $global:error.Clear()
        Remove-BoxstarterTask

        It "Should not populate error dictionary"{
            $global:error.count | should be 0
        }
    }
}
