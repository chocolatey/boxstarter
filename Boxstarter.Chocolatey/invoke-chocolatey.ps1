function Invoke-Chocolatey($chocoArgs) {
    Write-BoxstarterMessage "Current runtime is $($PSVersionTable.CLRVersion)" -Verbose
    $refs = @( 
        "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/log4net.dll",
        "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/chocolatey.dll"
    )
    $refs | % {
        Write-BoxstarterMessage "Adding types from $_" -Verbose
        Add-Type -Path $_
    }
    $cpar = New-Object System.CodeDom.Compiler.CompilerParameters
    $cpar.ReferencedAssemblies.Add([System.Reflection.Assembly]::Load('System.Management.Automation').location)
    $refs | % { $cpar.ReferencedAssemblies.Add($_) }
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
            try {
                if(_logDebug) _ui.WriteDebugLine(String.Format(message, formatting));
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
        }

        public void Debug(Func<string> message)
        {
            try {
                if(_logDebug) _ui.WriteDebugLine(message.Invoke());
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }

        }

        public void Info(string message, params object[] formatting)
        {
            try {
                _ui.WriteLine(String.Format(message, formatting));
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
        }

        public void Info(Func<string> message)
        {
            try {
                _ui.WriteLine(message.Invoke());
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }
        }

        public void Warn(string message, params object[] formatting)
        {
            try {
                _ui.WriteWarningLine(String.Format(message, formatting));
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }

        }

        public void Warn(Func<string> message)
        {
            try {
                _ui.WriteWarningLine(message.Invoke());
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
            }

        }

        public void Error(string message, params object[] formatting)
        {
            try {
                _ui.WriteErrorLine(String.Format(message, formatting));
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message);
            }

        }

        public void Error(Func<string> message)
        {
            try {
                _ui.WriteErrorLine(message.Invoke());
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message.Invoke());
            }

        }

        public void Fatal(string message, params object[] formatting)
        {
            try {
                _ui.WriteErrorLine(String.Format(message, formatting));
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message);
            }

        }

        public void Fatal(Func<string> message)
        {
            try {
                _ui.WriteErrorLine(message.Invoke());
            }
            catch(Exception e) {
                WriteRaw(e.ToString());
                WriteRaw(message.Invoke());
            }

        }

        private void WriteRaw(string message)
        {
            string path = @"c:\MyTest.txt";
            if (!File.Exists(path)) 
            {
                using (StreamWriter sw = File.CreateText(path)) 
                {
                    sw.WriteLine(message);
                }   
            }
            else {
                using (StreamWriter sw = File.AppendText(path)) 
                {
                    sw.WriteLine(message);
                }   
            }
        }
    }
}
"@ -CompilerParameters $cpar
    Write-BoxstarterMessage "Types added..." -Verbose
    if(!$global:choco) {
        Write-BoxstarterMessage "instantiating choco wrapper..." -Verbose
        $global:choco = New-Object -TypeName boxstarter.ChocolateyWrapper -ArgumentList `
          (Get-BoxstarterSetup),`
          $host.UI,`
          ($global:DebugPreference -eq "Continue")
    }

    Enter-BoxstarterLogable { 
        Write-BoxstarterMessage "calling choco now with $chocoArgs" -verbose
        $choco.Run($chocoArgs)
    }
}

function Get-BoxstarterSetup {
"Import-Module '$($boxstarter.BaseDir)\Boxstarter.chocolatey\Boxstarter.chocolatey.psd1' -DisableNameChecking -ArgumentList `$true"
}
