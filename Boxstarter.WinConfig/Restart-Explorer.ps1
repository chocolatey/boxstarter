function Restart-Explorer {

    try{
        #Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoRestartShell -Value 1 | out-Null
        $user = Get-CurrentUser
        Get-Process -Name explorer -ErrorAction SilentlyContinue -IncludeUserName | ? { $_.UserName -eq "$($user.Domain)\$($user.Name)"} | Stop-Process -Force -ErrorAction Stop | Out-Null

        Start-Sleep 1

        if(!(Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            start-Process -Name explorer
        }
    } catch {}
}
