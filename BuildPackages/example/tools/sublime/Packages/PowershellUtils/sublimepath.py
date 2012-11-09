# Path management utilities for Sublime plugin dev.
# TODO: This will eventually be moved to a separate package.
import sublime
import os

def rootAtPackagesDir(*leaf):
    return os.path.join(sublime.packages_path(), *leaf)
