<#
.SYNOPSIS
Sets the User Account Control (UAC) consent prompt behavior to specified value.

.LINK
https://boxstarter.org
Get-BoxstarterConsentPromptBehaviorAdmin
#>
function Set-BoxstarterConsentPromptBehaviorAdmin {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [Validateset(
            'NeverNotify', 
            'NotifyOnAppInstallWithoutDimming', 
            'NotifyOnAppInstall', 
            'PromptForConsent', 
            'PromptForCredentials', 
            'AlwaysNotify')]
        [string]
        $ConsentPromptBehavior
    )

    $hklmuac = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

    $uacState = Get-ItemProperty -Path $hklmuac -Name EnableLUA -ErrorAction SilentlyContinue
    if ($null -eq $uacState -or $uacState.EnableLUA -eq 0) {
        Enable-UAC
    }

    $valAdmin, $valSecDesktop = switch ($ConsentPromptBehavior) {
        'NeverNotify' { 0, 0 }
        'NotifyOnAppInstallWithoutDimming' { 5, 0 }
        'NotifyOnAppInstall' { 5, 1 }
        'AlwaysNotify' { 2, 1 }
    }
    Write-BoxstarterMessage "Setting ConsentPromptBehavior to $ConsentPromptBehavior"
    Set-ItemProperty -Path $hklmuac -Name ConsentPromptBehaviorAdmin -Value $valAdmin -Type DWord -Force
    Set-ItemProperty -Path $hklmuac -Name PromptOnSecureDesktop -Value $valSecDesktop -Type DWord -Force
}