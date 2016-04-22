function Install-BoxstarterPinnedTaskBarItem {
<#
.SYNOPSIS
Creates an item in the task bar linking to the provided path. This wraps the original function from
chocolatey with a check for Win10. It uses syspin if Win10 is detected.

.PARAMETER TargetFilePath
The path to the application that should be launched when clicking on the task bar icon.

.EXAMPLE
Install-BoxstarterPinnedTaskBarItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio 11.0\Common7\IDE\devenv.exe"

This will create a Visual Studio task bar icon.

#>
param(
  [string] $targetFilePath
)

    Write-BoxstarterMessage "Running 'Install-BoxstarterPinnedTaskBarItem' with targetFilePath:`'$targetFilePath`'" -Verbose

    if($PSVersionTable.BuildVersion.Major -ge 10) {  
        try{
            if (test-path($targetFilePath)) {
                $syspin = "$PSScriptRoot\bin\syspin.exe"
                . $syspin "$targetFilePath" c:5386
                Write-BoxstarterMessage "`'$targetFilePath`' has been pinned to the task bar on your desktop"
            } else {
                $errorMessage = "`'$targetFilePath`' does not exist, not able to pin to task bar"
            }

            if ($errorMessage) {
                Write-BoxstarterMessage $errorMessage -Color Yellow
            }
        } catch {
            Write-BoxstarterMessage "Unable to create pin. Error captured was $($_.Exception.Message)." -Color Red
            $global:Error.RemoveAt(0)
        }
    } else {
        Install-ChocolateyPinnedTaskBarItem -targetFilePath $targetFilePath
    }
}
