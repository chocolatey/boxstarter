function Format-BoxstarterMessage {
    param($BoxstarterMessage)
        if(Get-IsRemote){
        $BoxstarterMessage = "[$env:Computername]$BoxstarterMessage"
    }
    return $BoxstarterMessage
}
