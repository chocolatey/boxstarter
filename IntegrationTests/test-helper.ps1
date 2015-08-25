$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. $here\..\Boxstarter.Chocolatey\Send-File.ps1

function Invoke-LocalBoxstarterRun {
    [CmdletBinding()]
    param(
        [string]$BaseDir,
        [string]$VMName,
        [Management.Automation.PsCredential]$Credential,
        [string]$PackageName
    )
    $result = @{}

    $conn = Enable-BoxstarterVM -VMName $VMName -Credential $credential
    Write-Host "Creating session on $ConnectionURI"
    $session = New-PsSession -ConnectionURI $Conn.ConnectionURI -Credential $Credential
    Remove-PreviousState $session

    Setup-BoxstarterModuleAndLocalRepo $baseDir $session | Out-Null

    start-task $session $credential $packageName

    $start = Get-Date
    Write-Host "Waiting for Boxstarter run to complete..."
    do {
        if((Get-Date).Subtract($start).TotalSeconds -gt 300){
            throw "Exceeded 5 minute timeout to run boxstarter"
        }
        start-sleep 2
    }
    until (wait-task ([ref]$session) $conn.ConnectionURI $credential $result)

    $result.Session = $session
    $result.BoxstarterDir = Get-BoxDir
    New-TestResult $result
}

function New-TestResult($result) {
    $obj = New-Object PSObject -Prop $result
    $obj | Add-Member -MemberType ScriptMethod -Name InvokeOnTarget -Value {
        param($session, $script)
        Invoke-Command -Session $session -ScriptBlock $script
    }
    $result.Error = $obj.InvokeOnTarget($result.Session, {
        Get-Content -Path "$boxDir\test_error.txt" -ErrorAction SilentlyContinue
    })
    $obj
}

function start-task($session, $credential, $packageName) {
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
        schtasks /RUN /I /TN 'Boxstarter Task' | Out-Null
    } -ArgumentList @($Credential, $packageName)
}

function Setup-BoxstarterModuleAndLocalRepo($BaseDir, $session){
    Invoke-Command -Session $Session { mkdir $env:temp\boxstarter\BuildPackages -Force  | out-Null }
    Send-File "$BaseDir\Boxstarter.Chocolatey\Boxstarter.zip" "Boxstarter\boxstarter.zip" $session
    Get-ChildItem "$BaseDir\BuildPackages\*.nupkg" | % { 
        Write-host "Copying $($_.Name) to $($Session.ConnectionURI)"
        Send-File "$($_.FullName)" "Boxstarter\BuildPackages\$($_.Name)" $session 
    }
    Write-Host "Expanding modules on $($Session.ConnectionURI)"
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

function wait-task([ref]$session, $ConnectionURI, $credential, $result) {
    if(!(Test-Session $session.value)) {
        if($session.value -ne $null) {
            write-host "session failed $($session.value.Availability)"
            try { 
                    Remove-PSSession $session.value -ErrorAction SilentlyContinue
                    Write-Host "removed session after test failure"
                } 
                catch {}
        }
        $session.value = $null
        try { 
                $session.value = New-PsSession -ConnectionURI $ConnectionURI -Credential $Credential -ErrorAction Stop
                Write-Host "created new session. Availability: $($session.value.Availability)"
            }
            catch {
                write-host "error reestablishing session $_"
            }
    }

    if($session.value -eq $null) { return $false }

    try {
        Invoke-Command -session $session.value {
            param($boxDir)
            Test-Path "$boxDir\test_marker"
        } -ArgumentList (Get-BoxDir $credential) -ErrorAction Stop
    }
    catch{
        try {
            Write-Host "removing session - reboot likely in progress"
            $result.Rebooted = $true
            Remove-PSSession $session.value -ErrorAction SilentlyContinue
            Write-Host "session removed"
        }
        catch {}
        $session.value = $null
    }
}

function Get-BoxDir($credential) {
    "c:\users\$($credential.UserName)\appdata\local\temp\boxstarter"
}

function Test-Session($session) {
    $session -ne $null -and $session.Availability -eq "Available"
}

function Remove-PreviousState($session) {
    Invoke-Command -session $session {
        param($boxDir)
        Remove-Item -Path "$boxDir\test_marker" -ErrorAction SilentlyContinue | out-Null
        Remove-Item -Path "$boxDir\test_error.txt" -ErrorAction SilentlyContinue | Out-Null
    } -ArgumentList (Get-BoxDir $credential)
}