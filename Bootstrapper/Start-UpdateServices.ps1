function Start-UpdateServices {
    Start-Service -Name wuauserv
    Start-CCMEXEC
}

function Start-CCMEXEC {
    $ccm = get-service -include CCMEXEC
    if($ccm) {
        set-service CCMEXEC -startuptype automatic
        Start-Service CCMEXEC
    }
}