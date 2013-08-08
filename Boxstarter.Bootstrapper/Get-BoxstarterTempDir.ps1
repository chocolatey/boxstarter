function Get-BoxstarterTempDir {
    if(!(test-path "$env:LocalApData\Boxstarter")){mkdir "$env:LocalApData\Boxstarter"}
    return "$env:LocalApData\Boxstarter"
}