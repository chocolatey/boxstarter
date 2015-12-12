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
        private GetChocolatey _choco;
        
        public ChocolateyWrapper(string boxstarterSetup, PSHostUserInterface ui, bool logDebug, string logPath, bool quiet) {
            _choco = Lets.GetChocolatey();
            var psService = new PowershellService(new DotNetFileSystem(), boxstarterSetup);
            _choco.RegisterContainerComponent<IPowershellService>(() => psService);
            _choco.SetCustomLogging(new PsLogger(ui, logDebug, logPath, quiet));
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
        private bool _quiet;

        public PsLogger(PSHostUserInterface ui, bool logDebug, string path, bool quiet)
        {
            _ui = ui;
            _logDebug = logDebug;
            _path = path;
            _quiet = quiet;
        }

        public void InitializeFor(string loggerName)
        {
        }

        public void Debug(string message, params object[] formatting)
        {
            if(_quiet) return;
            try {
                var msg = String.Format(message, formatting);
                if(_logDebug) _ui.WriteDebugLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
        }

        public void Debug(Func<string> message)
        {
            if(_quiet) return;
            try {
                var msg = message.Invoke();
                if(_logDebug) _ui.WriteDebugLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }

        }

        public void Info(string message, params object[] formatting)
        {
            if(_quiet) return;
            var origColor = _ui.RawUI.ForegroundColor;
            try {
                var msg = String.Format(message, formatting);
                if(msg.Trim().StartsWith("Boxstarter: ") || msg.Replace("+","").Trim().StartsWith("Boxstarter ")){ 
                    _ui.RawUI.ForegroundColor = ConsoleColor.Green;
                }
                else {
                    _ui.RawUI.ForegroundColor = ConsoleColor.White;
                }
                _ui.WriteLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
            finally{
                _ui.RawUI.ForegroundColor = origColor;
            }
        }

        public void Info(Func<string> message)
        {
            if(_quiet) return;
            var origColor = _ui.RawUI.ForegroundColor;
            try {
                var msg = message.Invoke();
                if(msg.Trim().StartsWith("Boxstarter: ") || msg.Replace("+","").Trim().StartsWith("Boxstarter ")){ 
                    _ui.RawUI.ForegroundColor = ConsoleColor.Green;
                }
                else {
                    _ui.RawUI.ForegroundColor = ConsoleColor.White;
                }
                _ui.WriteLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
            finally{
                _ui.RawUI.ForegroundColor = origColor;
            }
        }

        public void Warn(string message, params object[] formatting)
        {
            if(_quiet) return;
            var origColor = _ui.RawUI.ForegroundColor;
            _ui.RawUI.ForegroundColor = ConsoleColor.Yellow;
            try {
                var msg = String.Format(message, formatting);
                _ui.WriteLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
            finally{
                _ui.RawUI.ForegroundColor = origColor;
            }
        }

        public void Warn(Func<string> message)
        {
            if(_quiet) return;
            var origColor = _ui.RawUI.ForegroundColor;
            _ui.RawUI.ForegroundColor = ConsoleColor.Yellow;
            try {
                var msg = message.Invoke();
                _ui.WriteLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
            finally{
                _ui.RawUI.ForegroundColor = origColor;
            }
        }

        public void Error(string message, params object[] formatting)
        {
            if(_quiet) return;
            try {
                var msg = String.Format(message, formatting);
                _ui.WriteErrorLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message);
            }

        }

        public void Error(Func<string> message)
        {
            if(_quiet) return;
            try {
                var msg = message.Invoke();
                _ui.WriteErrorLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message.Invoke());
            }

        }

        public void Fatal(string message, params object[] formatting)
        {
            if(_quiet) return;
            try {
                var msg = String.Format(message, formatting);
                _ui.WriteErrorLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message);
            }

        }

        public void Fatal(Func<string> message)
        {
            if(_quiet) return;
            try {
                var msg = message.Invoke();
                _ui.WriteErrorLine(msg);
                WriteRaw(msg);
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message.Invoke());
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

    if(!$global:choco) {
        Write-BoxstarterMessage "instantiating choco wrapper..." -Verbose
        $global:choco = New-Object -TypeName boxstarter.ChocolateyWrapper -ArgumentList `
          (Get-BoxstarterSetup),`
          $host.UI,`
          ($global:DebugPreference -eq "Continue"),`
          $boxstarter.log,`
          $boxstarter.SuppressLogging
    }

    Enter-BoxstarterLogable { 
        Write-BoxstarterMessage "calling choco now with $chocoArgs" -verbose
        $cd = [System.IO.Directory]::GetCurrentDirectory()
        try {
            # Chocolatey.dll uses GetCurrentDirectory which is not quite right
            # when calling via powershell. so we set it here
            [System.IO.Directory]::SetCurrentDirectory((Get-Location).Path)
            $choco.Run($chocoArgs)
        }
        finally {
            [System.IO.Directory]::SetCurrentDirectory($cd)
        }
    }
}

function Get-BoxstarterSetup {
"Import-Module '$($boxstarter.BaseDir)\Boxstarter.chocolatey\Boxstarter.chocolatey.psd1' -DisableNameChecking -ArgumentList `$true"
}
