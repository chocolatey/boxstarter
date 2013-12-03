$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Invoke-Verbosely" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
        % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$false
    
    Context "When Verbose is specified"{

        $msg = "this is verbose"
        $result = (Invoke-Verbosely -Verbose { Write-BoxstarterMessage $msg -Verbose } 4>&1 | Out-String)

        It "Should write to the verbose stream"{
            $result | should Match $msg
        }
    }

    Context "When Verbose is not specified"{

        $msg = "this is verbose"
        $result = (Invoke-Verbosely { Write-BoxstarterMessage $msg -Verbose } 4>&1 | Out-String)

        It "Should write to the verbose stream"{
            $result | should Not Match $msg
        }
    }
}