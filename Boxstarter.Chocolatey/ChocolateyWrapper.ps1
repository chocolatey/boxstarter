Add-Type @"
namespace Boxstarter
{
    using chocolatey;
    using chocolatey.infrastructure.app.services;
    using chocolatey.infrastructure.filesystem;
    using chocolatey.infrastructure.logging;
    using System;
    using System.Management.Automation.Host;

    public class ChocolateyWrapper
    {
        private GetChocolatey _choco;
        
        public ChocolateyWrapper(string boxstarterSetup, PSHostUserInterface ui, bool logDebug) {
            _choco = Lets.GetChocolatey();
            var psService = new PowershellService(new DotNetFileSystem(), boxstarterSetup);
            _choco.RegisterContainerComponent<IPowershellService>(() => psService);
            _choco.SetCustomLogging(new PsLogger(ui, logDebug));
        }

        public void Run(string[] args) {
            _choco.RunConsole(args);
        }
    }

    public class PsLogger : ILog
    {
        private PSHostUserInterface _ui;
        private Boolean _logDebug;

        public PsLogger(PSHostUserInterface ui, bool logDebug)
        {
            _ui = ui;
            _logDebug = logDebug;
        }

        public void InitializeFor(string loggerName)
        {
        }

        public void Debug(string message, params object[] formatting)
        {
            if(_logDebug) _ui.WriteDebugLine(String.Format(message, formatting));
        }

        public void Debug(Func<string> message)
        {
            if(_logDebug) _ui.WriteDebugLine(message.Invoke());
        }

        public void Info(string message, params object[] formatting)
        {
            _ui.WriteLine(String.Format(message, formatting));
        }

        public void Info(Func<string> message)
        {
            _ui.WriteLine(message.Invoke());
        }

        public void Warn(string message, params object[] formatting)
        {
            _ui.WriteWarningLine(String.Format(message, formatting));
        }

        public void Warn(Func<string> message)
        {
            _ui.WriteWarningLine(message.Invoke());
        }

        public void Error(string message, params object[] formatting)
        {
            _ui.WriteErrorLine(String.Format(message, formatting));
        }

        public void Error(Func<string> message)
        {
            _ui.WriteErrorLine(message.Invoke());
        }

        public void Fatal(string message, params object[] formatting)
        {
            _ui.WriteErrorLine(String.Format(message, formatting));
        }

        public void Fatal(Func<string> message)
        {
            _ui.WriteErrorLine(message.Invoke());
        }
    }
}
"@ -ReferencedAssemblies @( "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/chocolatey.dll" )
