function Log-BoxStarterMessage {
    param($title)
    if($Boxstarter.Log) {
        "[$(Get-Date -format o)] $title" | out-file $Boxstarter.Log -append
    }
}