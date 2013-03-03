function Start-UpdateServices {
    Write-BoxstarterMessage "Starting Windows Update Service"
    Enter-BoxstarterLogable { Start-Service -Name wuauserv }
    Start-CCMEXEC
}

function Start-CCMEXEC {
    $ccm = get-service -include CCMEXEC
    if($ccm) {
        Write-BoxstarterMessage "Starting Configuration Manager Service"
        set-service CCMEXEC -startuptype automatic
        Enter-BoxstarterLogable { Start-Service CCMEXEC }
    }
}