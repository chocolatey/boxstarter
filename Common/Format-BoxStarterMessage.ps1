<#A Build step copies this function to bootstrapper and Helpers Directory. Only edit script in Common#>
function Format-BoxStarterMessage {
    param($BoxStarterMessage)
    $columns=$host.UI.RawUI.MaxWindowSize.Width
    $msgSize=$BoxStarterMessage.Length + 2 #a empty space on both sides
    $extraSpace=$columns-$msgSize
    if($extraSpace -gt 5) {
        $sideSpace=[Math]::Floor($extraSpace/2)
    }
    else {$sideSpace=3}
    $padCars="".PadLeft($sideSpace,"*")
    return "$padCars $BoxStarterMessage $padCars"
}