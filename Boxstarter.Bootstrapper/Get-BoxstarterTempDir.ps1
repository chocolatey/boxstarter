function Get-BoxstarterTempDir {
    if($env:LocalAppData -and $env:LocalAppData.StartsWith("$env:SystemDrive\Users")){
        $dir = $env:LocalAppData
    }
    else {
        $dir = $env:ProgramData
    }

if(!(Test-Path "$dir\Boxstarter")){mkdir "$dir\Boxstarter" | out-null}
    return "$dir\Boxstarter"
}