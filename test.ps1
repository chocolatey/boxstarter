Start-Transcript -path test.txt
write-host "from write host"
write-output "from write output"
write-Error "this is an error"
tf workspaces
Stop-Transcript