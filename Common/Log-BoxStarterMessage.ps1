<#A Build step copies this function to bootstrapper and Helpers Directory. Only edit script in Common#>
function Log-BoxStarterMessage {
    param($title)
    if($Boxstarter.Log) {
        "[$(Get-Date -format o)] $title" | out-file $Boxstarter.Log -append
    }
}