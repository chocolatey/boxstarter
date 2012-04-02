import os
import uuid


import sublime, sublime_plugin


from sublime_lib.view import has_file_ext, in_one_edit
from sublime_lib.path import root_at_data, root_at_packages


JSON_TMLANGUAGE_SYNTAX = 'Packages/AAAPackageDev/Support/Sublime JSON Syntax Definition.tmLanguage'


# XXX: Move this to a txt file. Let user define his own under User too.
def get_syntax_def_boilerplate():
    JSON_TEMPLATE = """{ "name": "${1:Syntax Name}",
  "scopeName": "source.${2:syntax_name}", 
  "fileTypes": ["$3"], 
  "patterns": [$0
  ],
  "uuid": "%s"
}"""

    actual_tmpl = JSON_TEMPLATE % str(uuid.uuid4())
    return actual_tmpl


class NewSyntaxDefCommand(sublime_plugin.WindowCommand):
    """Creates a new syntax definition file for Sublime Text in JSON format
    with some boilerplate text.
    """
    def run(self):
        target = self.window.new_file()
        
        target.settings().set('default_dir', root_at_packages('User'))
        target.settings().set('syntax', JSON_TMLANGUAGE_SYNTAX)
        
        target.run_command('insert_snippet',
                           {'contents': get_syntax_def_boilerplate()})


class NewSyntaxDefFromBufferCommand(sublime_plugin.TextCommand):
    """Inserts boilerplate text for syntax defs into current view.
    """
    def is_enabled(self):
        # Don't mess up a non-empty buffer.
        return self.view.size() == 0

    def run(self, edit):
        self.view.settings().set('default_dir', root_at_packages('User'))
        self.view.settings().set('syntax', JSON_TMLANGUAGE_SYNTAX)

        with in_one_edit(self.view):
            self.view.run_command('insert_snippet',
                                  {'contents': get_syntax_def_boilerplate()})


# XXX: Why is this a WindowCommand? Wouldn't it work otherwise in build-systems?
class MakeTmlanguageCommand(sublime_plugin.WindowCommand):
    """Generates a ``.tmLanguage`` file from a ``.JSON-tmLanguage`` syntax def.
    Should be used from a ``.build-system only``.
    """
    # XXX: We whould prevent this from working except if called in a build system.
    def is_enabled(self):
        return has_file_ext(self.window.active_view(), '.JSON-tmLanguage')

    def run(self, **kwargs):
        v = self.window.active_view()
        path = v.file_name()
        if not (os.path.exists(path) and has_file_ext(v, 'JSON-tmLanguage')):
            # XXX: Can we/Should we use sublimelog.log?
            print "[AAAPackageDev] Not a valid JSON-tmLanguage file. (%s)" % path
            return

        build_cmd = root_at_data("Packages/AAAPackageDev/Support/make_tmlanguage.py")
        file_regex = r"Error:\s+'(.*?)'\s+.*?\s+line\s+(\d+)\s+column\s+(\d+)"
        cmd = ["python", build_cmd, path]

        self.window.run_command("exec", {"cmd": cmd, "file_regex": file_regex})
