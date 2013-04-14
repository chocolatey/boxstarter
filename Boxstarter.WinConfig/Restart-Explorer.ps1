function Restart-Explorer {
    Stop-Process -processname explorer -Force | Out-Null
}
