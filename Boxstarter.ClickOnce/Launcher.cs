using System.Deployment.Application;
using System.Diagnostics;
using System.Reflection;
using System.Security.Principal;
using System.Web;

namespace Boxstarter.WebLaunch
{
    public class Launcher
    {
        public static void Main(string[] args)
        {
            var psArgs = string.Empty;
            if (args.Length > 0)
            {
                psArgs = args[0];
                if (args.Length > 1)
                {
                    psArgs += " -DisableReboots";
                }
            }
            else if (ApplicationDeployment.IsNetworkDeployed && ApplicationDeployment.CurrentDeployment.ActivationUri != null)
            {
                var queryString = ApplicationDeployment.CurrentDeployment.ActivationUri.Query;
                if(queryString != null)
                {
                    psArgs = HttpUtility.ParseQueryString(queryString)["package"];
                    if(HttpUtility.ParseQueryString(queryString)["noreboot"] != null)
                    {
                        psArgs += " -DisableReboots";
                    }
                }

            }

            var fileToRun = "boxstarter.bat";
            if (!IsRunAsAdministrator())
            {
                fileToRun = Assembly.GetExecutingAssembly().CodeBase;
            }
            else
            {
                psArgs += " -KeepWindowOpen";
            }

            var processInfo = new ProcessStartInfo(fileToRun)
            {
                Verb = "runas",
                Arguments = psArgs
            };
            Process.Start(processInfo);
        }

        private static bool IsRunAsAdministrator()
        {
            var wi = WindowsIdentity.GetCurrent();
            var wp = new WindowsPrincipal(wi);

            return wp.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }
}
