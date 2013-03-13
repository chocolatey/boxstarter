class Plugin(object):
    def onNew(self, view):
        pass
    def onClone(self, view):
        pass
    def onLoad(self, view):
        pass
    def onClose(self, view):
        pass
    def onPreSave(self, view):
        pass
    def onPostSave(self, view):
        pass
    def onModified(self, view):
        pass
    def onSelectionModified(self, view):
        pass
    def onActivated(self, view):
        pass
    def onProjectLoad(self, window):
        pass
    def onProjectClose(self, window):
        pass


class ApplicationCommand(Plugin):
    pass


class WindowCommand(Plugin):
    pass


class TextCommand(Plugin):
    pass


class TextCommand(Plugin):
    def run(self, view, args):
        pass
    def isEnabled(self, view, args):
        pass
