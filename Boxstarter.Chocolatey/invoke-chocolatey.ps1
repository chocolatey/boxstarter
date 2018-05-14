function Invoke-Chocolatey($chocoArgs) {
    Write-BoxstarterMessage "Current runtime is $($PSVersionTable.CLRVersion)" -Verbose
    $refs = @(
        "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/log4net.dll",
        "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/chocolatey.dll"
    )
    $refs | % {
        Write-BoxstarterMessage "Adding types from $_" -Verbose
        if($env:TestingBoxstarter) {
            Write-BoxstarterMessage "loading choco bytes" -Verbose
            [System.Reflection.Assembly]::Load([io.file]::ReadAllBytes($_))
        }
        else {
            Write-BoxstarterMessage "loading choco from path" -Verbose
            Add-Type -Path $_
        }
    }
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

    if(!$env:ChocolateyInstall) {
        [System.Environment]::SetEnvironmentVariable('ChocolateyInstall', "$env:programdata\chocolatey", 'Machine')
        $env:ChocolateyInstall = "$env:programdata\chocolatey"
    }

    if(!(Test-Path "$env:ChocolateyInstall\lib")) {
        mkdir "$env:ChocolateyInstall\lib" | Out-Null
    }

    if(!$global:choco) {
        Write-BoxstarterMessage "instantiating choco wrapper..." -Verbose
        $global:choco = New-Object -TypeName boxstarter.ChocolateyWrapper -ArgumentList `
          (Get-BoxstarterSetup),`
          $host.UI,`
          ($global:DebugPreference -eq "Continue"),`
          ($global:VerbosePreference -eq "Continue"),`
          $boxstarter.log,`
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
"Import-Module '$($boxstarter.BaseDir)\Boxstarter.chocolatey\Boxstarter.chocolatey.psd1' -DisableNameChecking -ArgumentList `$true"
}
