import json
import plistlib
import os

def make_grammar(json_grammar):
    path, fname = os.path.split(json_grammar)
    grammar_name, ext = os.path.splitext(fname)

    with open(json_grammar) as grammar_in_json:
        tmlanguage = json.load(grammar_in_json)

    target = os.path.join(path, grammar_name + '.tmLanguage')
    if os.path.exists(target): os.remove(target)
    plistlib.writePlist(tmlanguage, target)
