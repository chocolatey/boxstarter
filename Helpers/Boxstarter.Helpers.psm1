# Boxstarter.Helpers
# Version: $version$
# Changeset: $sha$

$helpersPath = (Split-Path -parent $MyInvocation.MyCommand.Definition);
function Is64Bit {  [IntPtr]::Size -eq 8  }
Resolve-Path $helpersPath\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains(".Tests.")) } |
    % { . $_.ProviderPath }

Export-ModuleMember Disable-UAC, `
                    Enable-UAC, `
                    Get-UAC, `
                    Disable-InternetExplorerESC, `
                    Get-ExplorerOptions, `
                    Set-TaskbarSmall, `
                    Install-WindowsUpdate, `
                    Move-LibraryDirectory, `
                    Enable-RemoteDesktop, `
                    Set-ExplorerOptions, `
                    Get-LibraryNames, `
                    Update-ExecutionPolicy
