function Export-InternetExplorerESC {
<#
.SYNOPSIS
Exports the IE Enhanced Security Configuration

.LINK
http://boxstarter.org

#>
    $key = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
	
	Write-BoxstarterMessage "Exporting IE Enhanced Security configuration..."

	$args = @()
    if(Test-Path $key){
		$args += if ((Get-ItemProperty $key).IsInstalled -eq 0) { "Disable-InternetExplorerESC" }
    }
    
	[PSCustomObject]@{"Command" = $args }
}