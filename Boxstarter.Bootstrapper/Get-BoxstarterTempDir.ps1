function Get-BoxstarterTempDir {

    if ($PSVersionTable.Platform -eq 'Unix') {
        $dir = $env:HOME
    } else {
        if($env:LocalAppData -and $env:LocalAppData.StartsWith("$env:SystemDrive\Users")){
            $dir = $env:LocalAppData
        }
        else {
            $dir = $env:ProgramData
        } 
    }

if(!(Test-Path "$dir/Boxstarter")){mkdir "$dir/Boxstarter" | Out-Null}
    return "$dir/Boxstarter"
}
