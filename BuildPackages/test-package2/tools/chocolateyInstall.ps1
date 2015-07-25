Write-Host "a test package just installed. yo2"
gci env:
Get-LibraryNames
Add-Content "$env:temp\testpackage.txt" -value "test-package"