
function Expand-ZipFile($ZipFilePath, $DestinationFolder) {
    if ($PSVersionTable.PSVersion.Major -ge 4) {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipFilePath)

            foreach ($entry in $archive.Entries) {
                $entryTargetFilePath = [System.IO.Path]::Combine($DestinationFolder, $entry.FullName)
                $entryDir = [System.IO.Path]::GetDirectoryName($entryTargetFilePath)

                if (!(Test-Path $entryDir)) {
                    New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
                }

                if (!$entryTargetFilePath.EndsWith("/")) {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $true);
                }
            }
        }
        catch {
            throw $_
        }
    }
    else {
        #original method
        $shellApplication = new-object -com shell.application
        $zipPackage = $shellApplication.NameSpace($ZipFilePath)
        $DestinationF = $shellApplication.NameSpace($DestinationFolder)
        $DestinationF.CopyHere($zipPackage.Items(), 0x10)
    }
}


function Invoke-Chocolatey($chocoArgs) {
    Write-BoxstarterMessage "Current runtime is $($PSVersionTable.CLRVersion)" -Verbose

    if (-Not $env:ChocolateyInstall) {
        [System.Environment]::SetEnvironmentVariable('ChocolateyInstall', "$env:programdata\chocolatey", 'Machine')
        $env:ChocolateyInstall = "$env:programdata\chocolatey"
    }

    if (-Not (Test-Path $env:ChocolateyInstall)) {
        Write-BoxstarterMessage "SNAP! Chocolatey seems to be missing! - installing NOW!"
        $boxstarterZip = Get-Item "$($boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.zip"
        $tmpBoxstarterUnzipPath = "$($env:temp)\boxstarter_temp"
        Expand-ZipFile -ZipFilePath $boxstarterZip.FullName -DestinationFolder $tmpBoxstarterUnzipPath
        $chocoNupkg = Get-Item "$tmpBoxstarterUnzipPath\Boxstarter.Chocolatey\chocolatey\*.nupkg" | Select-Object -First 1
        Expand-ZipFile -ZipFilePath $chocoNupkg.FullName -DestinationFolder $env:temp\boxstarter_chocolatey
        Import-Module $env:temp\boxstarter_chocolatey\tools\chocolateysetup.psm1 -DisableNameChecking
        Initialize-Chocolatey
    }

    if (-Not (Test-Path "$env:ChocolateyInstall\lib")) {
        mkdir "$env:ChocolateyInstall\lib" | Out-Null
    }

    Enter-BoxstarterLogable {
        Write-BoxstarterMessage "calling choco now with $chocoArgs" -Verbose
        $cd = [System.IO.Directory]::GetCurrentDirectory()
        try {
            Write-BoxstarterMessage "setting current directory location to $((Get-Location).Path)" -Verbose
            [System.IO.Directory]::SetCurrentDirectory("$(Convert-Path (Get-Location).Path)")
            
            Write-BoxstarterMessage "BoxstarterWrapper::Run($chocoArgs)..." -Verbose
            $pargs = @{
                FilePath          = Join-Path $env:ChocolateyInstall 'choco.exe'
                ArgumentList      = $chocoArgs
                NoNewWindow       = $true
                PassThru          = $true
                UseNewEnvironment = $false
                Wait              = $true
            }
            $p = Start-Process @pargs -Verbose
            Write-BoxstarterMessage "BoxstarterWrapper::Run => $($p.ExitCode)" -Verbose
            [System.Environment]::ExitCode = $p.ExitCode

        }
        finally {
            Write-BoxstarterMessage "restoring current directory location to $cd" -Verbose
            [System.IO.Directory]::SetCurrentDirectory($cd)
        }
    }
}

function Get-BoxstarterSetup {
    "Import-Module '$($boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1' -DisableNameChecking -ArgumentList `$true"
}
