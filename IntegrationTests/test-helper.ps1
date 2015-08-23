$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. $here\..\Boxstarter.Chocolatey\Send-File.ps1


function Invoke-LocalBoxstarterRun {
    [CmdletBinding()]
    param(
        [string]$BaseDir,
        [string]$ComputerName,
        [Management.Automation.PsCredential]$Credential,
        [string]$PackageName
    )
    Write-Host "Creating session on $ComputerName"
    $session = New-PsSession -ComputerName $ComputerName -Credential $Credential

    Setup-BoxstarterModuleAndLocalRepo $baseDir $session

    Invoke-Command -Session $session { 
        param($Credential, $packageName)
        Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        $taskAction = @"
            `$secpasswd = ConvertTo-SecureString "$($Credential.GetNetworkCredential().Password)" -AsPlainText -Force
            `$credential = New-Object System.Management.Automation.PSCredential ("$($credential.UserName)", `$secpasswd)
            Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1 -DisableNameChecking
            Install-BoxstarterPackage -PackageName $packageName -Credential `$Credential
"@
        Set-Content $env:temp\BoxstarterTask.ps1 -value $taskAction -force
        schtasks /RUN /I /TN 'Boxstarter Task'
    } -ArgumentList @($Credential, $packageName)

}

function Setup-BoxstarterModuleAndLocalRepo($BaseDir, $session){
    Invoke-Command -Session $Session { mkdir $env:temp\boxstarter\BuildPackages -Force  | out-Null }
    Send-File "$BaseDir\Boxstarter.Chocolatey\Boxstarter.zip" "Boxstarter\boxstarter.zip" $session
    Get-ChildItem "$BaseDir\BuildPackages\*.nupkg" | % { 
        Write-host "Copying $($_.Name) to $($Session.ComputerName)"
        Send-File "$($_.FullName)" "Boxstarter\BuildPackages\$($_.Name)" $session 
    }
    Write-Host "Expanding modules on $($Session.ComputerName)"
    Invoke-Command -Session $Session {
        Set-ExecutionPolicy Bypass -Force
        $shellApplication = new-object -com shell.application 
        $zipPackage = $shellApplication.NameSpace("$env:temp\Boxstarter\Boxstarter.zip") 
        $destinationFolder = $shellApplication.NameSpace("$env:temp\boxstarter") 
        $destinationFolder.CopyHere($zipPackage.Items(),0x10)
        [xml]$configXml = Get-Content (Join-Path $env:temp\Boxstarter BoxStarter.config)
        if($configXml.config.LocalRepo -ne $null) {
            $configXml.config.RemoveChild(($configXml.config.ChildNodes | ? { $_.Name -eq "LocalRepo"}))
            $configXml.Save((Join-Path $env:temp\Boxstarter BoxStarter.config))
        }
    }
}
