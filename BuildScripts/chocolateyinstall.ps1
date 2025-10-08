$tools = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
. (Join-Path $tools Setup.ps1)
try {
    $ModuleName = (Get-ChildItem $tools | Where-Object { $_.PSIsContainer }).BaseName
    if (-not $ModuleName) {
        throw "No module found in $tools"
    }
    Write-Verbose "Installing Boxstarter module $ModuleName"
    $preInstall = Join-Path $tools "$modulename.preinstall.ps1"
    if (Test-Path $preInstall) { 
        Write-Verbose "Running pre-install script: $preInstall"
        . $preInstall 
    }
    Write-Verbose 'Install-Boxstarter ...'
    Install-Boxstarter $tools $ModuleName $env:chocolateyPackageParameters
}
catch {
    Write-Output "An error occurred during installation of Boxstarter module $ModuleName"
    Write-Output 'Error details:'
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Verbose 'Full error details:'
    $_.Exception | Format-List * -Force | Write-Verbose
    throw $_.Exception
}
