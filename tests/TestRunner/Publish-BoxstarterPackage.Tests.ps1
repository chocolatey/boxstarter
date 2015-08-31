$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.TestRunner){Remove-Module Boxstarter.TestRunner}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.TestRunner\*.ps1 | 
    ? { $_.Path -like "*-*" } | 
    % { . $_.ProviderPath }

Describe "Publish-BoxstarterPackage" {
    $Boxstarter.LocalRepo=(Get-PSDrive TestDrive).Root
    $Boxstarter.SuppressLogging=$true
    $ProgressPreference="SilentlyContinue"
    Mock Invoke-NugetPush
    Mock Get-BoxstarterPackagePublishedVersion { [Version]"3.0.0.0" }

    Context "When successfully publishing a package" {
        $pkgName="package1"
        [Uri]$feed="http://myfeed"
        Set-BoxstarterFeedAPIKey $feed ([guid]::NewGuid())
        $publishedVersion="3.0.0.0"
        Mock Get-BoxstarterPackage {
            New-Object PSObject -Property @{
                Id = $pkgName
                Version = "3.0.0.0"
                PublishedVersion=$publishedVersion
                Feed=$feed
            }
        }

        $result = $pkgName | Publish-BoxstarterPackage

        it "Should return the name of the published package" {
            $result.Package | should be $pkgName 
        }
        it "Should return the feed of the published package" {
            $result.Feed | should be $feed 
        }
        it "Should have matching repo and published versions" {
            $result.PublishedVersion | should be $publishedVersion
        }
    }

    Context "When publishing a package not in the repo" {
        $global:Error.Clear()
        $pkgName="package1"

        $result = Publish-BoxstarterPackage "package1" 2>$err 

        it "Package returned should have package name" {
            $result.Package | should be "package1"
        }
        it "should write InvalidArgument error" {
            $global:Error[0].CategoryInfo.Category | should be "InvalidArgument"
        }
        it "Should include error in Publish errors" {
            $result.PublishErrors | should be $global:Error[0].Exception.Message
        }
    }

    Context "When package has no feed" {
        $global:Error.Clear()
        $pkgName="package1"
        Mock Get-BoxstarterPackage {
            New-Object PSObject -Property @{
                Id = $pkgName
                Version = "2.0.0.0"
            }
        }

        $result = Publish-BoxstarterPackage $pkgName 2>$err 

        it "should write InvalidArgument error" {
            $global:Error[0].CategoryInfo.Category | should be "InvalidOperation"
        }
        it "Should include error in Publish errors" {
            $result.PublishErrors | should be $global:Error[0].Exception.Message
        }
    }

    Context "When no API key exists for the feed" {
        $global:Error.Clear()
        $pkgName="package1"
        [Uri]$feed="http://myfeed"
        $publishedVersion="3.0.0.0"
        Mock Get-BoxstarterPackage {
            New-Object PSObject -Property @{
                Id = $pkgName
                Version = "2.0.0.0"
                PublishedVersion=$publishedVersion
                Feed=$feed
            }
        }

        $result = Publish-BoxstarterPackage $pkgName 2>$err 

        it "should write InvalidArgument error" {
            $global:Error[0].CategoryInfo.Category | should be "InvalidOperation"
        }
        it "Should include error in Publish errors" {
            $result.PublishErrors | should be $global:Error[0].Exception.Message
        }
    }

    Context "When nuget throws an error" {
        $global:Error.Clear()
        $pkgName="package1"
        [Uri]$feed="http://myfeed"
        $key=
        Set-BoxstarterFeedAPIKey $feed ([guid]::NewGuid())
        $script:testing=$true
        Mock Get-BoxstarterPackage {
            New-Object PSObject -Property @{
                Id = $pkgName
                Version = "3.0.0.0"
                Feed=$feed
            }
        }
        $nugetError = & "$env:ChocolateyInstall\bin\Nuget.exe" push "yadayadayada" 2>&1
        Mock Invoke-NugetPush { & "$env:ChocolateyInstall\bin\Nuget.exe" push "yadayadayada"  }
        Mock Get-BoxstarterPackagePublishedVersion { [Version]"2.0.0.0" }

        $result = Publish-BoxstarterPackage $pkgName 2>$err 

        it "should write nuget error" {
            $global:Error[0].Exception.Message | should be ($nugetError -Join ", ")
        }
        it "Should include error in Publish errors" {
            $result.PublishErrors[0] | should be $nugetError[0]
            $result.PublishErrors[1].ToString() | should be $nugetError[1].ToString()
        }
    }

    Context "When rest call for published version throws an error" {
        $global:Error.Clear()
        $pkgName="package1"
        [Uri]$feed="http://myfeed"
        Set-BoxstarterFeedAPIKey $feed ([guid]::NewGuid())
        $publishedVersion="3.0.0.0"
        Mock Get-BoxstarterPackage {
            New-Object PSObject -Property @{
                Id = $pkgName
                Version = "2.0.0.0"
                PublishedVersion=$publishedVersion
                Feed=$feed
            }
        }
        $restException = new-Object -TypeName Exception -ArgumentList "blah"
        Mock Get-BoxstarterPackagePublishedVersion { throw $restException  }

        $result = Publish-BoxstarterPackage $pkgName 2>$err 

        it "should write nuget error" {
            $global:Error[0].Exception.Message | should be $restException.Message
        }
        it "Should include error in Publish errors" {
            $result.PublishErrors | should be $restException.Message
        }
    }

    Context "When rest call for published version returns previous version" {
        $global:Error.Clear()
        $pkgName="package1"
        [Uri]$feed="http://myfeed"
        Set-BoxstarterFeedAPIKey $feed ([guid]::NewGuid())
        $publishedVersion="2.0.0.0"
        Mock Get-BoxstarterPackage {
            New-Object PSObject -Property @{
                Id = $pkgName
                Version = "3.0.0.0"
                PublishedVersion=$publishedVersion
                Feed=$feed
            }
        }
        $Script:counter=0
        Mock Get-BoxstarterPackagePublishedVersion { 
            $Script:counter += 1
            if($Script:counter -lt 3) {return "2.0.0.0"}else{return "3.0.0.0"}
        }

        $result = Publish-BoxstarterPackage $pkgName

        it "Should have matching repo and published versions" {
            $result.PublishedVersion | should be "3.0.0.0"
        }
    }
}