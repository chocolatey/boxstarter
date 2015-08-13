function Enter-Dotnet4 {
    param([ScriptBlock]$net4Script, [object[]]$ArgumentList)
    Enable-Net40
    if($PSVersionTable.CLRVersion.Major -lt 4) {
        Write-BoxstarterMessage "Relaunching powershell under .net fx v4" -verbose
        $env:COMPLUS_version="v4.0.30319"
        & powershell -OutputFormat Text -ExecutionPolicy bypass -command $net4Script -args $ArgumentList
    }
    else {
        Write-BoxstarterMessage "Using current powershell..." -verbose
        Invoke-Command -ScriptBlock $net4Script -argumentlist $ArgumentList
    }
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
        Write-BoxstarterMessage "Downloading .net 4.5..."
        Get-HttpToFile "http://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe" "$env:temp\net45.exe"
        Write-BoxstarterMessage "Installing .net 4.5..."
        if(Get-IsRemote) {
            Invoke-FromTask @"
Start-Process "$env:temp\net45.exe" -verb runas -wait -argumentList "/quiet /norestart /log $env:temp\net45.log"
"@
        }
        else {
            $proc = Start-Process "$env:temp\net45.exe" -verb runas -argumentList "/quiet /norestart /log $env:temp\net45.log" -PassThru 
            while(!$proc.HasExited){ sleep -Seconds 1 }
        }
    }
}

function Get-HttpToFile ($url, $file){
    Write-BoxstarterMessage "Downloading $url to $file" -Verbose
    Invoke-RetriableScript -RetryScript {
        if(Test-Path $args[1]){Remove-Item $args[1] -Force}
        $downloader=new-object net.webclient
        $wp=[system.net.WebProxy]::GetDefaultProxy()
        $wp.UseDefaultCredentials=$true
        $downloader.Proxy=$wp
        try {
            $downloader.DownloadFile($args[0], $args[1])
        }
        catch{
            if($VerbosePreference -eq "Continue"){
                Write-Error $($_.Exception | fl * -Force | Out-String)
            }
            throw $_
        }
    } $url $file
}
