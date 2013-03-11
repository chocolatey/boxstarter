$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}

Describe "Set-BoxstarterShare" {
    $testRoot=(Get-PSDrive TestDrive).Root
    Import-Module "$here\..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1"

    Context "When setting share with no parameters" {
        MkDir "$testRoot\boxstarter" | Out-Null
        $Boxstarter.BaseDir="$testRoot\Boxstarter"

        Set-BoxstarterShare

        It "Should create Boxstarter Share"{
            Test-Path "\\$env:Computername\Boxstarter" | should be $true
        }
        It "Should give read access to everyone"{
            (net share Boxstarter) | ? { $_.StartsWith("Permission")} | % { $_.ToLower().EndsWith("everyone, read") | Should be $true}
        }
        net share Boxstarter /delete
    }

    Context "When setting share with another Name" {
        MkDir "$testRoot\boxstarter" | Out-Null
        $Boxstarter.BaseDir="$testRoot\Boxstarter"

        Set-BoxstarterShare "ShareName"

        It "Should create Share"{
            Test-Path "\\$env:Computername\ShareName" | should be $true
        }
        It "Should give read access to everyone"{
            (net share ShareName) | ? { $_.StartsWith("Permission")} | % { return $_.ToLower().EndsWith("everyone, read") | Should be $true}
        }
        net share ShareName /delete
    }

    Context "When setting share with a specific user" {
        MkDir "$testRoot\boxstarter" | Out-Null
        $Boxstarter.BaseDir="$testRoot\Boxstarter"

        Set-BoxstarterShare -Accounts "$env:UserDomain\$env:UserName"

        It "Should create Share"{
            Test-Path "\\$env:Computername\Boxstarter" | should be $true
        }
        It "Should give read access to account"{
            (net share Boxstarter) | ? { $_.StartsWith("Permission")} | % { return $_.Replace("Permission","").Trim() | should be "$env:UserDomain\$env:UserName, read" }
        }
        net share Boxstarter /delete
    }

    Context "When share already exists" {
        MkDir "$testRoot\boxstarter" | Out-Null
        $Boxstarter.BaseDir="$testRoot\Boxstarter"
        Net share Boxstarter="$($Boxstarter.BaseDir)"
        
        try {Set-BoxstarterShare} catch{$exception=$_}

        It "Should throw exception"{
            $exception | should not be $null
        }
        net share Boxstarter /delete
    }

    Context "When sharing with multiple accounts" {
        MkDir "$testRoot\boxstarter" | Out-Null
        $Boxstarter.BaseDir="$testRoot\Boxstarter"
        $expectedAccounts=@("Everyone","$env:UserDomain\$env:UserName")
        
        Set-BoxstarterShare -Accounts $expectedAccounts

        It "Should share with both accounts"{
            $accounts=@()
            foreach ($line in (net share Boxstarter)){
                if($line.Trim() -eq "The command completed successfully."){
                    break
                }
                if($line.StartsWith("Permission") -or ($Accounts.Length -gt 0)){
                    if($line.Trim().Length -gt 0){
                        $accounts += $line.Replace("Permission","").Trim()                        
                    }
                }
            }
            $accounts.Length | should be $expectedAccounts.Length
            foreach($account in $Accounts){
                $expectedAccounts -join " " | should match $account.Replace(", READ","").Replace("\","\\")
            }
        }
        net share Boxstarter /delete
    }
}