function Get-Conn{
    $cfg = New-Object -ComObject HNetCfg.HNetShare.1
    $all=$cfg.EnumEveryConnection
    foreach($conn in $all){
        $shareCfg=$cfg.INetSharingConfigurationForINetConnection($conn)
        $props=$cfg.NetConnectionProps($conn)
        $props
        $shareCfg
    }
}