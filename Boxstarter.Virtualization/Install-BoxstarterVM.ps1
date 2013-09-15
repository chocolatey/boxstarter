function Install-BoxstarterVM {
    param(
        [string]$package,
        [string]$vmName,
        [string]$vmCheckpoint
    )
    $creds = Get-Credential -Message "$vmName credentials" -UserName "$env:UserDomain\$env:username"
    Enable-VMPSRemoting $vmName $creds

    $me=$env:computername
    $remoteDir = $Boxstarter.BaseDir.replace(':','$')
    $encryptedPass = convertfrom-securestring -securestring $creds.password
    $modPath="\\$me\$remoteDir\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1"
    $script = {
        Import-Module $args[0]
        Invoke-ChocolateyBoxstarter $args[1] -Password $args[2]
    }
    Write-BoxstarterMessage "Importing Boxstarter Module at $modPath"
    Invoke-Command -ComputerName (Get-GuestComputerName $vmName) -Credential $creds -Authentication Credssp -ScriptBlock $script -Argumentlist $modPath,$package,$creds.Password
}