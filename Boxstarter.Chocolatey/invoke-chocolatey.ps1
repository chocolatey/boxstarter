
function Expand-ZipFile($ZipFilePath, $DestinationFolder) {
    if ($PSVersionTable.PSVersion.Major -ge 4) {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipFilePath)

            foreach ($entry in $archive.Entries) {
                $entryTargetFilePath = [System.IO.Path]::Combine($DestinationFolder, $entry.FullName)
                $entryDir = [System.IO.Path]::GetDirectoryName($entryTargetFilePath)

                if (!(Test-Path $entryDir)) {
                    New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
                }

                if (!$entryTargetFilePath.EndsWith("/")) {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $true);
                }
            }
        }
        catch {
            throw $_
        }
    }
    else {
        #original method
        $shellApplication = new-object -com shell.application
        $zipPackage = $shellApplication.NameSpace($ZipFilePath)
        $DestinationF = $shellApplication.NameSpace($DestinationFolder)
        $DestinationF.CopyHere($zipPackage.Items(), 0x10)
    }
}


function Invoke-Chocolatey($chocoArgs) {
    Write-BoxstarterMessage "Current runtime is $($PSVersionTable.CLRVersion)" -Verbose

    if (-Not $env:ChocolateyInstall) {
        [System.Environment]::SetEnvironmentVariable('ChocolateyInstall', "$env:programdata\chocolatey", 'Machine')
        $env:ChocolateyInstall = "$env:programdata\chocolatey"
    }

    if (-Not (Test-Path $env:ChocolateyInstall)) {
        Write-BoxstarterMessage "SNAP! Chocolatey seems to be missing! - installing NOW!"
        $boxstarterZip = Get-Item "$($boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.zip"
        $tmpBoxstarterUnzipPath = "$($env:temp)\boxstarter_temp"
        Expand-ZipFile -ZipFilePath $boxstarterZip.FullName -DestinationFolder $tmpBoxstarterUnzipPath
        $chocoNupkg = Get-Item "$tmpBoxstarterUnzipPath\Boxstarter.Chocolatey\chocolatey\*.nupkg" | Select-Object -First 1
        Expand-ZipFile -ZipFilePath $chocoNupkg.FullName -DestinationFolder $env:temp\boxstarter_chocolatey
        Import-Module $env:temp\boxstarter_chocolatey\tools\chocolateysetup.psm1 -DisableNameChecking
        Initialize-Chocolatey
    }

    if (-Not (Test-Path "$env:ChocolateyInstall\lib")) {
        mkdir "$env:ChocolateyInstall\lib" | Out-Null
    }

    $refs = @(
        "$($env:ChocolateyInstall)/choco.exe"
    )
            
    # FIXME wir müssen einen "hook" hinbekommen, sodass
    # => boxstarter module/cmdlets/VARIABLEN im scope der choco.exe bekannt sind
    # => weitere "choco" calls in einem Choco Pkg nicht an Chocolatey, sondern an die entsprechenden Boxstarter funktionen gehen
    #    (sollte durch obigen Punkt automagisch gelöst sein)

    # möglicher Workaround: "ur-version von MattWrock, aber choco.exe anstelle von dll laden?"
    $refs | % {
        Write-BoxstarterMessage "loading choco bytes" -Verbose
        [System.Reflection.Assembly]::Load([io.file]::ReadAllBytes($_))
    }
    <#
    Enter-BoxstarterLogable {

        if (-Not $Boxstarter.LetsGetChocolatey) {
            Write-BoxstarterMessage "calling 'boxstarter choco' now - setting up environment with '$chocoArgs'" -Verbose

            $setupEnvScript = [scriptblock]::Create((Get-BoxstarterSetup))
            $Boxstarter.LetsGetChocolatey = $true

            $wrapperScript = {
                param($verbosity, $thisBoxstarter, $chocoArgs)
                $Global:VerbosePreference = $verbosity
                $global:Boxstarter = $thisBoxstarter

                Write-BoxstarterMessage "calling LetsGetchocolatey => 'choco $chocoArgs'" -Verbose
                & choco $chocoArgs
            }

            $Boxstarter.Keys | % {
                Write-Host "(ii) $_ -> $($Boxstarter[$_])"    
            }
            Write-Host "(ii) chocoArgs: $chocoArgs"

            $jobArgs = @{
                InitializationScript = $setupEnvScript
                ScriptBlock          = $wrapperScript
                ArgumentList         = @($Global:VerbosePreference, $Boxstarter, $chocoArgs)
                Verbose              = $VerbosePreference
            }
            
            $wrapperJob = Start-Job @jobArgs
            Receive-Job -Job $wrapperJob -Wait -AutoRemoveJob

        }
        else {
            Write-BoxstarterMessage "calling actual choco.exe now with '$chocoArgs'" -Verbose
            $cd = [System.IO.Directory]::GetCurrentDirectory()
            try {
                Write-BoxstarterMessage "setting current directory location to $((Get-Location).Path)" -Verbose
                [System.IO.Directory]::SetCurrentDirectory("$(Convert-Path (Get-Location).Path)")
                
                Write-BoxstarterMessage "BoxstarterWrapper::Run($chocoArgs)..." -Verbose
                $pargs = @{
                    FilePath          = Join-Path $env:ChocolateyInstall 'choco.exe'
                    ArgumentList      = $chocoArgs.Split(" ")
                    NoNewWindow       = $true
                    PassThru          = $true
                    UseNewEnvironment = $false
                    Wait              = $true
                }
                
                $p = Start-Process @pargs -Verbose
                Write-BoxstarterMessage "BoxstarterWrapper::Run => $($p.ExitCode)" -Verbose
                [System.Environment]::ExitCode = $p.ExitCode

            }
            finally {
                Write-BoxstarterMessage "restoring current directory location to $cd" -Verbose
                [System.IO.Directory]::SetCurrentDirectory($cd)
            }
            
        }       
    }
    #>

    $cpar = New-Object System.CodeDom.Compiler.CompilerParameters
    $cpar.ReferencedAssemblies.Add([System.Reflection.Assembly]::Load('System.Management.Automation').location) | Out-Null
    $refs | % { $cpar.ReferencedAssemblies.Add($_) | Out-Null }
    Write-BoxstarterMessage "Adding boxstarter choco wrapper types..." -Verbose
    Add-Type @"
namespace Boxstarter
{
    using chocolatey;
    using chocolatey.infrastructure.app.services;
    using chocolatey.infrastructure.filesystem;
    using chocolatey.infrastructure.logging;
    using System;
    using System.IO;
    using System.Management.Automation.Host;

    public class ChocolateyWrapper
    {
        private static GetChocolatey _choco;

        public ChocolateyWrapper(string boxstarterSetup, PSHostUserInterface ui, bool logDebug, bool logVerbose, string logPath, bool quiet) {
            if (_choco == null) {
                _choco = Lets.GetChocolatey();
                var psService = new PowershellService(new DotNetFileSystem(), boxstarterSetup);
                _choco.RegisterContainerComponent<IPowershellService>(() => psService);
            }
            _choco.SetCustomLogging(new PsLogger(ui, logDebug, logVerbose, logPath, quiet));
        }

        public void Run(string[] args) {
            _choco.RunConsole(args);
        }
    }

    public class PsLogger : ILog
    {
        private PSHostUserInterface _ui;
        private string _path;
        private bool _logDebug;
        private bool _logVerbose;
        private bool _quiet;

        public PsLogger(PSHostUserInterface ui, bool logDebug, bool logVerbose, string path, bool quiet)
        {
            _ui = ui;
            _logDebug = logDebug;
            _logVerbose = logVerbose;
            _path = path;
            _quiet = quiet;
        }

        public void InitializeFor(string loggerName)
        {
        }

        public void Debug(string message, params object[] formatting)
        {
            WriteLog(
                message,
                x => { if(_logDebug) _ui.WriteDebugLine(x); },
                formatting
            );
        }

        public void Debug(Func<string> message)
        {
            WriteLog(
                message,
                x => { if(_logDebug) _ui.WriteDebugLine(x); }
            );
        }

        public void Info(string message, params object[] formatting)
        {
            WriteLog(
                message,
                x => {
                        if(x.Trim().StartsWith("Boxstarter: ") || x.Replace("+","").Trim().StartsWith("Boxstarter ")){
                            _ui.RawUI.ForegroundColor = ConsoleColor.Green;
                        }
                        else {
                            _ui.RawUI.ForegroundColor = ConsoleColor.White;
                        }
                        if(x.Trim().StartsWith("VERBOSE: ")) {
                            if(_logVerbose) _ui.WriteVerboseLine(x);
                        }
                        else {
                            _ui.WriteLine(x);
                        }
                    },
                formatting
            );
        }

        public void Info(Func<string> message)
        {
            WriteLog(
                message,
                x => {
                        if(x.Trim().StartsWith("Boxstarter: ") || x.Replace("+","").Trim().StartsWith("Boxstarter ")){
                            _ui.RawUI.ForegroundColor = ConsoleColor.Green;
                        }
                        else {
                            _ui.RawUI.ForegroundColor = ConsoleColor.White;
                        }
                        if(x.Trim().StartsWith("VERBOSE: ")) {
                            if(_logVerbose) _ui.WriteVerboseLine(x);
                        }
                        else {
                            _ui.WriteLine(x);
                        }
                    }
            );
        }

        public void Warn(string message, params object[] formatting)
        {
            WriteLog(
                message,
                x => {
                        _ui.RawUI.ForegroundColor = ConsoleColor.Yellow;
                        _ui.WriteLine(x);
                    },
                formatting
            );
        }

        public void Warn(Func<string> message)
        {
            WriteLog(
                message,
                x => {
                        _ui.RawUI.ForegroundColor = ConsoleColor.Yellow;
                        _ui.WriteLine(x);
                    }
            );
        }

        public void Error(string message, params object[] formatting)
        {
            WriteLog(
                message,
                x => _ui.WriteErrorLine(x),
                formatting
            );
        }

        public void Error(Func<string> message)
        {
            WriteLog(
                message,
                x => _ui.WriteErrorLine(x)
            );
        }

        public void Fatal(string message, params object[] formatting)
        {
            WriteLog(
                message,
                x => _ui.WriteErrorLine(x),
                formatting
            );
        }

        public void Fatal(Func<string> message)
        {
            WriteLog(
                message,
                x => _ui.WriteErrorLine(x)
            );
        }

        private void WriteLog(string message, Action<String> logAction, params object[] formatting)
        {
            WriteFormattedLog(() => String.Format(message, formatting), logAction);
        }

        private void WriteLog(Func<string> message, Action<String> logAction)
        {
            WriteFormattedLog(() => message.Invoke(), logAction);
        }

        private void WriteFormattedLog(Func<string> formatMessage, Action<String> logAction)
        {
            if(_quiet) return;
            var origColor = _ui.RawUI.ForegroundColor;
            try {
                var msg = formatMessage.Invoke();
                logAction.Invoke(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
            finally{
                _ui.RawUI.ForegroundColor = origColor;
            }
        }

        private void WriteRaw(string message)
        {
            if(String.IsNullOrEmpty(_path))
                return;
            try {
                using (FileStream fs = new FileStream(_path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite))
                {
                    using (StreamWriter sw = new StreamWriter(fs, System.Text.Encoding.UTF8))
                    {
                        sw.WriteLine(message);
                    }
                }
            }
            catch(Exception e)
            {
                _ui.WriteErrorLine(e.ToString());
            }
        }
    }
}
"@ -CompilerParameters $cpar
    Write-BoxstarterMessage "Types added..." -Verbose


    if (!$global:choco) {
        Write-BoxstarterMessage "instantiating choco wrapper..." -Verbose
        $global:choco = New-Object -TypeName boxstarter.ChocolateyWrapper -ArgumentList `
        (Get-BoxstarterSetup), `
            $host.UI, `
        ($global:DebugPreference -eq "Continue"), `
        ($global:VerbosePreference -eq "Continue"), `
            $boxstarter.log, `
            $boxstarter.SuppressLogging
    }

    Enter-BoxstarterLogable {
        Write-BoxstarterMessage "calling choco now with $chocoArgs" -Verbose
        $cd = [System.IO.Directory]::GetCurrentDirectory()
        try {
            # Chocolatey.dll uses GetCurrentDirectory which is not quite right
            # when calling via PowerShell. so we set it here
            Write-BoxstarterMessage "setting current directory location to $((Get-Location).Path)" -Verbose
            [System.IO.Directory]::SetCurrentDirectory("$(Convert-Path (Get-Location).Path)")
            $choco.Run($chocoArgs)
        }
        finally {
            Write-BoxstarterMessage "restoring current directory location to $cd" -Verbose
            [System.IO.Directory]::SetCurrentDirectory($cd)
        }
    }


}

function Get-BoxstarterSetup {
    "Import-Module '$($boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1' -DisableNameChecking -ArgumentList `$true"
}
