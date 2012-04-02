import json
import plistlib
import os
import sys


def make_tmlanguage_grammar(json_grammar):
    path, fname = os.path.split(json_grammar)
    grammar_name, ext = os.path.splitext(fname)

    try:
        with open(json_grammar) as grammar_in_json:
            tmlanguage = json.load(grammar_in_json)
    except ValueError, e:
        # Avoid DeprecationWarning by not calling e.message.
        sys.stderr.write("Error: '%s' %s" % (json_grammar, str(e)))
    else:
        target = os.path.join(path, grammar_name + '.tmLanguage')
        print "Writing tmLanguage... (%s)" % target
        plistlib.writePlist(tmlanguage, target)
    

if __name__ == '__main__':
    path = sys.argv[1]
    make_tmlanguage_grammar(path)