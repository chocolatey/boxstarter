function Format-BoxStarterMessage {
    param($BoxStarterMessage)
        if(Get-IsRemote){
        $BoxStarterMessage = "[$env:Computername]$BoxStarterMessage"
    }
    return $BoxStarterMessage
}
