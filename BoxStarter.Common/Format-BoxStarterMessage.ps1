<#A Build step copies this function to bootstrapper and Helpers Directory. Only edit script in Common#>
function Format-BoxStarterMessage {
    param($BoxStarterMessage)
    #I could put some crazy formatting here...if I wanted to.
    return $BoxStarterMessage
}