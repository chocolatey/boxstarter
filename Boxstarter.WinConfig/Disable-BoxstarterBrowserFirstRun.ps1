function Disable-BoxstarterBrowserFirstRun {
    <#
    .SYNOPSIS
    Turns off IE and Edge first run customization wizards.

    .LINK
    https://boxstarter.org

    .EXAMPLE
    Disable-BrowserFirstRun

    Turns off IE and Edge first run customization wizards.
    #>
    $RegistryKeys = @(
        @{ Key = 'HKLM:\Software\Policies\Microsoft\Edge' ; Value = 'HideFirstRunExperience' } # Edge
        @{ Key = 'HKLM:\Software\Microsoft\Internet Explorer\Main' ; Value = 'DisableFirstRunCustomize' } # Internet Explorer 11
        @{ Key = 'HKLM:\Software\Policies\Microsoft\Internet Explorer\Main' ; Value = 'DisableFirstRunCustomize' } # Internet Explorer 9
    )

    foreach ($Key in $RegistryKeys) {
        if (-not (Test-Path $Key.Key)) {
            New-Item -Path $Key.Key -Force
        }

        New-ItemProperty -Path $Key.Key -Name $Key.Value -Value 1 -PropertyType DWORD -Force
    }

    Write-Output "IE and Edge first run customizations wizards have been disabled."
}
