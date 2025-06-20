function Get-BoxstarterConsentPromptBehaviorAdmin {
    <#
https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsb/341747f5-6b5d-4d30-85fc-fa1cc04038d4

	
0x00000000 -> "NeverNotify"
0x00000001 -> "NotifyOnAppInstallWithoutDimming"
0x00000002 -> "NotifyOnAppInstall"
0x00000003 -> "PromptForConsent"
0x00000004 -> "PromptForCredentials"
0x00000005 -> "AlwaysNotify"
    #>

    $state = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue
    if ($null -eq $state) {  
        Write-BoxstarterMessage "ConsentPromptBehaviorAdmin is not set. Defaulting to 'AlwaysNotify'."
        return 'AlwaysNotify'
    }
    switch ($state.ConsentPromptBehaviorAdmin) {
        0 { return 'NeverNotify' }
        1 { return 'NotifyOnAppInstallWithoutDimming' }
        2 { return 'NotifyOnAppInstall' }
        3 { return 'PromptForConsent' }
        4 { return 'PromptForCredentials' }
        5 { return 'AlwaysNotify' }
        default {
            Write-BoxstarterMessage "Unknown ConsentPromptBehaviorAdmin value: $($state.ConsentPromptBehaviorAdmin). Defaulting to 'AlwaysNotify'."
            return 'AlwaysNotify'
        }
    }
}