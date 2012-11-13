function Restart-Explorer {
    Stop-Process -processname explorer -Force
    start-process $env:systemroot\explorer.exe
}
