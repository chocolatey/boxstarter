$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.bootstrapper){Remove-Module boxstarter.bootstrapper}
Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.BoxstarterUser="user"
$Boxstarter.SuppressLogging=$true
$Boxstarter.NoPassword=$false
$Boxstarter.ScriptToCall="some script"

Describe "Invoke-Reboot" {
    Mock New-Item -ParameterFilter { $Path -like "*boxstarter*" }
    Mock Restart
    $Boxstarter.SourcePID=500
    if(get-module Bitlocker -ListAvailable){Mock Suspend-Bitlocker}

    Context "When reboots are suppressed" {
        $Boxstarter.RebootOk=$false
        $Boxstarter.IsRebooting=$false
        
        Invoke-Reboot

        it "will not create Restart script file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*Boxstarter.script" } -times 0
        }
        it "will not restart" {
            Assert-MockCalled Restart -times 0
        }
        it "will not toggle reboot" {
            $Boxstarter.IsRebooting | should be $false
        }
        it "will not create Restart marker file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*.restart" } -times 0
        }
    }

    Context "When reboots are not suppressed" {
        $Boxstarter.RebootOk=$true
        $Boxstarter.IsRebooting=$false
        $bitlockerCommand = Get-Command -Name 'get-bitlockervolume' -ErrorAction SilentlyContinue
        if($bitlockerCommand){
            Mock Get-BitlockerVolume {@{ProtectionStatus="On";VolumeType="operatingSystem"}}
        }

        Invoke-Reboot

        it "will create Restart script file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*Boxstarter.script" }
        }
        it "will restart" {
            Assert-MockCalled Restart
        }
        it "will toggle reboot" {
            $Boxstarter.IsRebooting | should be $true
        }
        it "will suspend bitlocker" {
            if(get-module bitlocker -ListAvailable){Assert-MockCalled Suspend-Bitlocker}
        }
        it "will create Restart marker file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*boxstarter.500.restart" }
        }
    }

    Context "When reboots are not suppressed and no source pid" {
        $Boxstarter.RebootOk=$true
        $Boxstarter.IsRebooting=$false
        $Boxstarter.SourcePID=$null
        $bitlockerCommand = Get-Command -Name 'get-bitlockervolume' -ErrorAction SilentlyContinue
        if($bitlockerCommand){
            Mock Get-BitlockerVolume {@{ProtectionStatus="On";VolumeType="operatingSystem"}}
        }

        Invoke-Reboot

        it "will create Restart script file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*Boxstarter.script" }
        }
        it "will restart" {
            Assert-MockCalled Restart
        }
        it "will toggle reboot" {
            $Boxstarter.IsRebooting | should be $true
        }
        it "will suspend bitlocker" {
            if(get-module bitlocker -ListAvailable){Assert-MockCalled Suspend-Bitlocker}
        }
        it "will not create Restart marker file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*.restart" } -times 0
        }
    }

    Context "When Get-BitlockerVolume throws an error" {
        $Boxstarter.RebootOk=$true
        $Boxstarter.IsRebooting=$false
        $Boxstarter.SourcePID=500
        $bitlockerCommand = Get-Command -Name 'get-bitlockervolume' -ErrorAction SilentlyContinue
        if($bitlockerCommand){
            Mock Get-BitlockerVolume { throw "some crazy error." }
        }

        Invoke-Reboot

        it "will create Restart script file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*Boxstarter.script" }
        }
        it "will restart" {
            Assert-MockCalled Restart
        }
        it "will toggle reboot" {
            $Boxstarter.IsRebooting | should be $true
        }
        it "will create Restart marker file" {
            Assert-MockCalled New-Item -ParameterFilter { $Path -Like "*boxstarter.500.restart" }
        }
    }
}