<#
.SYNOPSIS
Retrieves the User Account Control (UAC) consent prompt behavior.

.LINK
https://boxstarter.org
Set-BoxstarterConsentPromptBehaviorAdmin
#>
function Get-BoxstarterConsentPromptBehaviorAdmin {
    [CmdletBinding()]

    $hklmuac = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

    $uacState = Get-ItemProperty -Path $hklmuac -Name EnableLUA -ErrorAction SilentlyContinue
    if ($null -eq $uacState) {
        # UAC is disable -> consent prompt behavior is irrelevant
        return $null
    }

    $stateAdmin = Get-ItemProperty -Path $hklmuac -Name ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue
    if ($null -eq $stateAdmin) {
        Write-BoxstarterMessage "ConsentPromptBehaviorAdmin is not set. Defaulting to 'AlwaysNotify'."
        return 'AlwaysNotify'
    }

    $statePrompt = Get-ItemProperty -Path $hklmuac -Name PromptOnSecureDesktop -ErrorAction SilentlyContinue
    switch ($stateAdmin.ConsentPromptBehaviorAdmin) {
        0 { return 'NeverNotify' }
        5 {
            if ($statePrompt.PromptOnSecureDesktop -eq 0) {
                return 'NotifyOnAppInstallWithoutDimming'
            }
            return 'NotifyOnAppInstall'
        }
        2 { return 'AlwaysNotify' }
        default {
            Write-BoxstarterMessage "Unknown ConsentPromptBehaviorAdmin value: $($stateAdmin.ConsentPromptBehaviorAdmin). Defaulting to 'AlwaysNotify'."
            return 'AlwaysNotify'
        }
    }
}