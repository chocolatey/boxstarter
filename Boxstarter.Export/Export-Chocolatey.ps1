function Export-Chocolatey {
<#
.SYNOPSIS
Exports packages installed via Chocolatey

.LINK
http://boxstarter.org
#>

    $isInstalled = Get-IsChocolateyInstalled;
    if (-not $isInstalled) {
        return;
    }

    Write-BoxstarterMessage "Exporting Chocolatey packages..."

    [Version]$chocoVersion = Get-ChocolateyVersion;
    
    $output = Get-LocalChocolateyPackages $chocoVersion

    $commands = $output | % { "choco install " + $_ }

    [PSCustomObject]@{"Command" = $commands; }
}

function Get-IsChocolateyInstalled {
     
     if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")) {
        Write-BoxstarterMessage "Chocolatey is not installed, skipping..."
        return $false;
     }

     return (Get-Command choco) -ne $null
}

function Get-ChocolateyVersion {
    & choco -v
}

function Get-LocalChocolateyPackages([Version]$version) {
    [Version]$newChoco = "0.9.9.0"

    $result = @()
    switch($version) {
            
        { $_ -ge $newChoco } {
            $list = & choco list -lo -r -y # get LocalOnly packages with minimal output, answer yes to all questions
            $result = $list | % { $_.Split('|') | select -First 1 }
        }
    }

    $result
}