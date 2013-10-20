function Format-BoxStarterMessage {
    param($BoxStarterMessage)
        if($PSSenderInfo.ApplicationArguments.RemoteBoxstarter -ne $null){
        $BoxStarterMessage = "[$env:Computername]$BoxStarterMessage"
    }
    return $BoxStarterMessage
}