$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Module boxstarter.*

Resolve-Path $here\..\..\boxstarter.WinConfig\*.ps1 | ForEach-Object { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.common\*.ps1 | ForEach-Object { . $_.ProviderPath }
$Boxstarter.SuppressLogging = $true

Describe "Disable-BingSearch" {

    Context "When running on a specific Windows release" {

        $testCases = @(
            @{  OSVersion = '10.0.0'
                KeyPath   = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
                KeyName   = 'BingSearchEnabled'
                KeyValue  = 0
            }
            @{ OSVersion = '10.0.19041'
                KeyPath  = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
                KeyName  = 'DisableSearchBoxSuggestions'
                KeyValue = 1
            }
            @{ OSVersion = '10.0.19042'
                KeyPath  = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
                KeyName  = 'DisableSearchBoxSuggestions'
                KeyValue = 1
            }
        )

        It 'should create the appropriate registry path, key and value' -TestCases $testCases {
            param ($OSVersion, $KeyPath, $KeyName, $KeyValue)

            Mock Get-CimInstance -MockWith { [pscustomobject]@{ Version = $OSVersion } }
            Mock New-Item  -Verifiable
            Mock New-ItemProperty -Verifiable
            if (Test-Path -Path $KeyPath) {
                $assertTimesCalled = 0
            }
            else {
                $assertTimesCalled = 1
            }

            Disable-BingSearch
            Assert-MockCalled -CommandName 'Get-CimInstance' -Exactly 1 -Scope It
            Assert-MockCalled -CommandName 'New-Item' -ParameterFilter { $Path -eq $KeyPath } -Exactly $assertTimesCalled -Scope It
            Assert-MockCalled -CommandName 'New-ItemProperty' `
                -ParameterFilter { $Path -eq $KeyPath `
                    -and $Name -eq $KeyName -and $Value -eq $KeyValue } -Exactly 1 -Scope It
        } #it
    } #context
}