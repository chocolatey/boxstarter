function Set-BoxstarterConsentPromptBehaviorAdmin {
    <#
.SYNOPSIS
Sets the User Account Control (UAC) consent prompt behavior to specified value.

https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsb/341747f5-6b5d-4d30-85fc-fa1cc04038d4

	
0x00000000 -> "NeverNotify"
0x00000001 -> "NotifyOnAppInstallWithoutDimming"
0x00000002 -> "NotifyOnAppInstall"
0x00000003 -> "PromptForConsent"
0x00000004 -> "PromptForCredentials" 
0x00000005 -> "AlwaysNotify"

.LINK
https://boxstarter.org

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [Validateset('NeverNotify', 'NotifyOnAppInstallWithoutDimming', 'NotifyOnAppInstall', 'PromptForConsent', 'PromptForCredentials', 'AlwaysNotify')]
        [string]
        $ConsentPromptBehavior
    )
    $value = switch ($ConsentPromptBehavior) {
        'NeverNotify' { 0 }
        'NotifyOnAppInstallWithoutDimming' { 1 }
        'NotifyOnAppInstall' { 2 }
        'PromptForConsent' { 3 }
        'PromptForCredentials' { 4 }
        'AlwaysNotify' { 5 }
    }
    Write-BoxstarterMessage "Setting ConsentPromptBehaviorAdmin to $ConsentPromptBehavior"
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
        -Name ConsentPromptBehaviorAdmin `
        -Value $value `
        -Type DWord `
        -Force
}