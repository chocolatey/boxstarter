$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

Describe "Enable-VMPSRemoting" {
    try {
        Remove-Module boxstarter.*
        Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
            % { . $_.ProviderPath }
        Resolve-Path $here\..\..\boxstarter.VirtualMachine\*-*.ps1 | 
            % { . $_.ProviderPath }
        $Boxstarter.SuppressLogging=$true
        $vhdFile="$env:temp\Boxstarter.vhd"
        New-Item $vhdFile -type file | Out-Null
        $vmname="vmname"
        $computername="ComputerName"
        $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
        $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)
        Mock Get-VM {"some vm"} -ParameterFilter {$Name -eq $vmname}
        Mock Stop-VM -ParameterFilter {$Name -eq $vmname}
        Mock Start-VM -ParameterFilter {$Name -eq $vmname}
        Mock Invoke-PSEXEC
        Mock GET-VMHardDiskDrive {@{Path="$vhdFile"}} -ParameterFilter {$VMName -eq $vmname}
        Mock Get-VHDComputerName {$computername}
        Mock Add-VHDStartupScript -ParameterFilter {$VHDPath -eq "$vhdFile"}
        Mock Wait-Port {$true} -ParameterFilter {$hostName -eq $computername}

        Context "When Enabling remoting is successful"{
            $result = Enable-VMPSRemoting $vmname $mycreds

            It "Should return winrm connection uri"{
                $result | should be "http://$computername:5985"
            }
        }
        
        Context "When VM Does not exist"{
            Mock Get-VM -ParameterFilter {$Name -eq $vmname}

            try {
                Enable-VMPSRemoting $vmname $mycreds | out-null
            }
            catch{
                $err = $_
            }

            It "Should throw a InvalidOperation Exception"{
                $err.CategoryInfo.Reason | should be "InvalidOperationException"
            }
        }
    }
    finally{
        del $env:temp\Boxstarter.vhd -force
    }
}