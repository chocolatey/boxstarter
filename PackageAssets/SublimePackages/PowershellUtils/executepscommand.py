from __future__ import with_statement
import os.path
import subprocess
import codecs
import ctypes
import tempfile
import functools
from xml.etree.ElementTree import ElementTree
import base64

import sublime, sublime_plugin

import sublimepath
from sublime_lib.view import append

# The PoSh pipeline provided by the user and the input values (regions)
# are merged with this template.
PoSh_SCRIPT_TEMPLATE = u"""
function collectData { "<out><![CDATA[$([string]::join('`n', $input))]]></out>`n" }
$script:pathToOutPutFile ="%s"
"<outputs>" | out-file $pathToOutPutFile -encoding utf8 -force
$script:regionTexts = %s
$script:regionTexts | foreach-object {
                        %s | out-string | collectData | out-file `
                                                    -filepath $pathToOutPutFile `
                                                    -append `
                                                    -encoding utf8
}
"</outputs>" | out-file $pathToOutPutFile -encoding utf8 -append -force
"""

THIS_PACKAGE_NAME = "PowershellUtils"
THIS_PACKAGE_DEV_NAME = "XXX" + THIS_PACKAGE_NAME
POSH_SCRIPT_FILE_NAME = "psbuff.ps1"
POSH_HISTORY_DB_NAME = "pshist.txt"
OUTPUT_SINK_NAME = "out.xml"
DEBUG = os.path.exists(sublime.packages_path() + "/" + THIS_PACKAGE_DEV_NAME)


class CantAccessScriptFileError(Exception):
    pass


def regions_to_posh_array(view, rgs):
    """
    Return a PoSh array: 'x', 'y', 'z' ... and escape single quotes like
    this : 'escaped ''sinqle quoted text'''
    """
    return ",".join("'%s'" % view.substr(r).replace("'", "''") for r in rgs)

def get_outputs():
    tree = ElementTree()
    tree.parse(get_path_to_output_sink())
    return [el.text[:-1] for el in tree.findall("out")]

def get_this_package_name():
    """
    Name varies depending on the name of the folder containing this code.
    TODO: Is __name__ accurate in Sublime? __file__ doesn't seem to be.
    """
    return THIS_PACKAGE_NAME if not DEBUG else THIS_PACKAGE_DEV_NAME

def get_path_to_posh_script():
    return sublimepath.rootAtPackagesDir(get_this_package_name(), POSH_SCRIPT_FILE_NAME)

def get_path_to_posh_history_db():
    return sublimepath.rootAtPackagesDir(get_this_package_name(), POSH_HISTORY_DB_NAME)

def get_path_to_output_sink():
    return sublimepath.rootAtPackagesDir(get_this_package_name(), OUTPUT_SINK_NAME)

def get_posh_saved_history():
    # If the command history file doesn't exist now, it will be created when
    # the user chooses to persist the current history for the first time.
    try:
        with open(get_path_to_posh_history_db(), 'r') as f:
            return [command[:-1].decode('utf-8') for command in f.readlines()]
    except IOError:
        return []

def get_oem_cp():
    # Windows OEM/Ansi codepage mismatch issue.
    # We need the OEM cp, because powershell is a console program.
    codepage = ctypes.windll.kernel32.GetOEMCP()
    return str(codepage)

def build_script(values, userPoShCmd):
    with codecs.open(get_path_to_posh_script(), 'w', 'utf_8_sig') as f:
        f.write( PoSh_SCRIPT_TEMPLATE % (get_path_to_output_sink(), values, userPoShCmd) )

def build_posh_cmd_line():
    return ["powershell",
                        "-noprofile",
                        "-nologo",
                        "-noninteractive",
                        # PoSh 2.0 lets you specify an ExecutionPolicy
                        # from the cmdline, but 1.0 doesn't.
                        "-executionpolicy", "remotesigned",
                        "-file", get_path_to_posh_script(), ]

def filter_thru_posh(values, userPoShCmd):

    try:
        build_script(values, userPoShCmd)
    except IOError:
        raise CantAccessScriptFileError

    # Hide the child process window.
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

    PoShOutput, PoShErrInfo = subprocess.Popen(build_posh_cmd_line(),
                                            stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE,
                                            startupinfo=startupinfo).communicate()

    return ( PoShOutput.decode(get_oem_cp()),
             PoShErrInfo.decode(get_oem_cp()), )


def run_posh_command(cmd):
    """Runs a command without taking into account Sublime regions for filtering.
    Output should be output to console.
    """
    encoded_cmd = cmd
    posh_cmdline = [
        "powershell.exe",
                        "-noprofile",
                        "-noninteractive",
                        "-nologo",
                        "-sta",
                        "-outputformat", "text",
                        "-command", encoded_cmd
    ]

    out, error = subprocess.Popen(posh_cmdline,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE).communicate()
    
    return (out.decode(get_oem_cp()),
            error.decode(get_oem_cp()),)


class RunPowershell(sublime_plugin.TextCommand):
    """
    This plugin provides an interface to filter text through a Windows
    Powershell (PoSh) pipeline. See README.TXT for instructions.
    """

    PoSh_HISTORY_MAX_LENGTH = 50
    PSHistory = get_posh_saved_history()
    lastFailedCommand = ""

    def _add_to_posh_history(self, command):
        # Comment out 'till the API is complete.
        #if not command in self.PSHistory:
        #    self.PSHistory.insert(0, command)
        #if len(self.PSHistory) > self.PowershellSh_HISTORY_MAX_LENGTH:
        #    self.PSHistory.pop()
        pass

    def _show_posh_history(self, view):
        sublime.error_message("Not implemented due to incomplete API.")
        # view.window().showQuickPanel('', "runExternalPSCommand", self.PSHistory,
        #                                 sublime.QUICK_PANEL_MONOSPACE_FONT)

    def _parse_intrinsic_commands(self, userPoShCmd, view):
        if userPoShCmd == '!h':
            if self.PSHistory:
                self._show_posh_history(view)
            else:
                sublime.status_message("Powershell command history is empty.")
            return True
        if userPoShCmd == '!mkh':
            try:
                with open(get_path_to_posh_history_db(), 'w') as f:
                    cmds = [(cmd + '\n').encode('utf-8') for cmd in self.PSHistory]
                    f.writelines(cmds)
                    sublime.status_message("Powershell command history saved.")
                return True
            except IOError:
                sublime.status_message("ERROR: Could not save Powershell command history.")
        else:
            return False

    def run(self, edit, initial_text='', command='', as_filter=True):
        if command:
            self.on_done(self.view, edit, command, as_filter)
            return

        # Open cmd line.
        initialText = initial_text or self.lastFailedCommand
        inputPanel = self.view.window().show_input_panel("PoSh cmd:", initialText, functools.partial(self.on_done, self.view, edit), None, None)

    def on_done(self, view, edit, userPoShCmd, as_filter=True):
        # Exit if user doesn't actually want to filter anything.
        if self._parse_intrinsic_commands(userPoShCmd, view): return

        # Run command, don't modify the buffer, output to output panel.
        if not as_filter:
            self.output_view = self.view.window().new_file()
            self.output_view.set_scratch(True)
            self.output_view.set_name("Powershell - Output")
            out, error = run_posh_command(userPoShCmd)
            if out or error:
                if out: append(self.output_view, out)
                if error: append(self.output_view, error)
            return

        try:
            PoShOutput, PoShErrInfo = filter_thru_posh(regions_to_posh_array(view, view.sel()), userPoShCmd)
        except EnvironmentError, e:
            sublime.error_message("Windows error. Possible causes:\n\n" +
                                  "* Is Powershell in your %PATH%?\n" +
                                  "* Use Start-Process to start ST from Powershell.\n\n%s" % e)
            return
        except CantAccessScriptFileError:
            sublime.error_message("Cannot access script file.")
            return

        # Inform the user that something went wrong in his PoSh code or
        # perform substitutions and do house-keeping.
        if PoShErrInfo:
            print PoShErrInfo
            sublime.status_message("PowerShell error.")
            self.view.window().run_command("show_panel", {"panel": "console"})
            self.lastFailedCommand = userPoShCmd
            return
        else:
            self.lastFailedCommand = ''
            self._add_to_posh_history(userPoShCmd)
            # Cannot do zip(regs, outputs) because view.sel() maintains
            # regions up-to-date if any of them changes.
            for i, txt in enumerate(get_outputs()):
                view.replace(edit, view.sel()[i], txt)
