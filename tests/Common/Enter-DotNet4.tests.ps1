$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Module boxstarter.*
Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.SuppressLogging=$true

Describe "Enter-DotNet4" {
    $currentCLR = $PSVersionTable.CLRVersion
    Mock Test-Path { $true } -ParameterFilter { $path.EndsWith('v4.0.30319') }
    Mock Test-PendingReboot { $false }
    Mock Get-IsRemote { $false }
    Mock Get-HttpResource
    Mock Start-Process { @{HasExited=$true} } -ParameterFilter { $FilePath.EndsWith("net45.exe") }
    $PSVersionTable.CLRVersion = New-Object Version '4.0.0'

    $result = Enter-Dotnet4 { Write-Output "$($args[0]):$PID" } 'PID'

    it 'should run in the same .net 4 process' {
        $result | should be "PID:$PID"
    }
    it 'should not download .net' {
        Assert-MockCalled Get-HttpResource -Times 0
    }
    it 'should not install .net' {
        Assert-MockCalled Start-Process -Times 0
    }


    context '.net 4 is not installed' {
        Mock Test-Path { $false } -ParameterFilter { $path.EndsWith('v4.0.30319') }

        Enter-Dotnet4 { Write-Output "$($args[0]):$PID" } 'PID' | Out-Null

        it 'downloads .net 4' {
            Assert-MockCalled Get-HttpResource
        }
        it 'installs .net 4' {
            Assert-MockCalled Start-Process
        }
    }

    context 'called remotely' {
        Mock Test-Path { $false } -ParameterFilter { $path.EndsWith('v4.0.30319') }
        Mock Get-IsRemote { $true }
        Mock Invoke-FromTask

        Enter-Dotnet4 { Write-Output "$($args[0]):$PID" } 'PID' | Out-Null

        it 'downloads .net 4' {
            Assert-MockCalled Get-HttpResource
        }
        it 'does not installs .net 4 in process' {
            Assert-MockCalled Start-Process -Times 0
        }
        it 'installs .net 4 from a task' {
            Assert-MockCalled Invoke-FromTask -ParameterFilter { $command -Like "Start-Process *"}
        }
    }

    context 'running in .net 2' {
        $PSVersionTable.CLRVersion = New-Object Version '2.0.0'

        $result = Enter-Dotnet4 { Write-Output "$($args[0]):$PID" } 'PID'

        it 'should run in a new process' {
            $result | should Match "PID:"
            $result | should Not Match "$PID"
        }
    }
    $PSVersionTable.CLRVersion = $currentCLR
}
