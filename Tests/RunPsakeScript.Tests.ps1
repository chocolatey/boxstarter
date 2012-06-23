$here = Split-Path -Parent $MyInvocation.MyCommand.Path
remove-Module AutoBox
import-module "$here\..\AutoBox.psm1"

    Describe "RunPsakeScript" {

        It "WillRunDefaultPsakeScriptDefaultTaskWhenNoParamsPassed" {
            try{
                $env:testScriptCalled=0
                new-item $here\..\BuildPackages\Default\default.ps1 -force -type file -value "Task default -depends t;Task t{`$env:testScriptCalled=1}"

                Invoke-Autobox

                $env:testScriptCalled.should.be(1)
            }
            finally{
                remove-Item $here\..\BuildPackages\Default\default.ps1
            }
        }
    }
