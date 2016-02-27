# we no longer use a dependeny on WindowsAzureLibsForNet
# Currently we MUST use version 2.5 and dependencies 
# broke if the user has a more recent version

if(Test-Path "$env:ProgramFiles\Microsoft SDKs\Azure\.NET SDK\v2.5") {
    Write-Host "Windows Azure Libraries for .net v2.5 is already installed."
    return
}
Install-ChocolateyPackage 'Boxstarter.WindowsAzureLibsForNet'`
                          'msi' '/quiet /norestart'`
                          'http://download.microsoft.com/download/9/F/7/9F7D3299-9AE1-40BE-B24F-C0E9EB0BE61E/MicrosoftAzureLibsForNet-x86.msi'`
                          'http://download.microsoft.com/download/9/F/7/9F7D3299-9AE1-40BE-B24F-C0E9EB0BE61E/MicrosoftAzureLibsForNet-x64.msi'
