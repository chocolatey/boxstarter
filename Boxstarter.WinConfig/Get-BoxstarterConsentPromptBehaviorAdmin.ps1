function Get-BoxstarterConsentPromptBehaviorAdmin {
    <#
https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpsb/341747f5-6b5d-4d30-85fc-fa1cc04038d4

    #>

    $state = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue
    if ($null -eq $state) {  
        Write-BoxstarterMessage "ConsentPromptBehaviorAdmin is not set. Defaulting to 'AlwaysNotify'."
        return 'AlwaysNotify'
    }
    switch ($state.ConsentPromptBehaviorAdmin) {
        0 { return 'NeverNotify' }
        # 5 { return 'NotifyOnAppInstallWithoutDimming' }
        5 { return 'NotifyOnAppInstall' }
        2 { return 'AlwaysNotify' }
        default {
            Write-BoxstarterMessage "Unknown ConsentPromptBehaviorAdmin value: $($state.ConsentPromptBehaviorAdmin). Defaulting to 'AlwaysNotify'."
            return 'AlwaysNotify'
        }
    }
}