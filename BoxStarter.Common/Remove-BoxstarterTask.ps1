function Remove-BoxstarterTask {
	schtasks /DELETE /TN 'Boxstarter Task' /F 2>&1 | Out-null
}