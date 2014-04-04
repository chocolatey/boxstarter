function Restart-Explorer {

    try{
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoRestartShell -Value 1 | out-Null
        Stop-Process -processname explorer -Force -ErrorAction Stop | Out-Null
    } catch {}
}
