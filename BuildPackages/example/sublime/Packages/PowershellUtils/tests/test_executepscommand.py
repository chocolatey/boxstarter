import unittest
import mock
import sublime
import ctypes

sublime.packagesPath = mock.Mock()
sublime.packagesPath.return_value = "XXX"

import sublimeplugin
import executepscommand

class SimpleTestCase(unittest.TestCase):

    def test_regionsToPoShArray(self):
        view = mock.Mock()
        rgs = ["'one'", "'two'", "three"]

        view.substr = mock.Mock()
        view.substr.side_effect = lambda x: x

        expected = "'''one''','''two''','three'"
        actual = executepscommand.regionsToPoShArray(view, rgs)

        self.assertEquals(expected, actual)

    def test_getThisPackageNameNonDebug(self):
        executepscommand.DEBUG = True
        expected = "XXXPowershellUtils"
        actual = executepscommand.getThisPackageName()

        self.assertEquals(expected, actual)

    def test_getThisPackageNameNonDebug(self):
        executepscommand.DEBUG = False
        expected = "PowershellUtils"
        actual = executepscommand.getThisPackageName()

        self.assertEquals(expected, actual)

    def test_getPathToPoShScript(self):
        expected = r"XXX\PowershellUtils\psbuff.ps1"
        actual = executepscommand.getPathToPoShScript()

        self.assertEquals(expected, actual)

    def test_getPathToPoShHistoryDB(self):
        expected = r"XXX\PowershellUtils\pshist.txt"
        actual = executepscommand.getPathToPoShHistoryDB()

        self.assertEquals(expected, actual)

    def test_getPathToOutputSink(self):
        expected = r"XXX\PowershellUtils\out.xml"
        actual = executepscommand.getPathToOutputSink()

        self.assertEquals(expected, actual)

    def test_buildPoShCmdLine(self):
        expected = ["powershell",
                        "-noprofile",
                        "-nologo",
                        "-noninteractive",
                        # PoSh 2.0 lets you specify an ExecutionPolicy
                        # from the cmdline, but 1.0 doesn't.
                        "-executionpolicy", "remotesigned",
                        "-file", executepscommand.getPathToPoShScript(), ]

        actual = executepscommand.buildPoShCmdLine()

        self.assertEquals(expected, actual)


class TestCase_Helpers(unittest.TestCase):

    def test_getOEMCP(self):

        expected = str(ctypes.windll.kernel32.GetOEMCP())
        actual = executepscommand.getOEMCP()

        self.assertEquals(expected, actual)


class TestCase_HistoryFunctionality(unittest.TestCase):

    def setUp(self):
        self.command = executepscommand.RunExternalPSCommandCommand()

    def test_NewCommandIsAppendedToHistory(self):
        self.command._addToPSHistory("1")

        self.assertEquals(["1"], self.command.PSHistory)

    def test_ExistingCommandIsDiscarded(self):

        self.command._addToPSHistory("1")
        self.command._addToPSHistory("1")

        self.assertEquals(len(self.command.PSHistory), 1)

    def test_HistoryIsPoppedIfUpperLimitIsExceeded(self):

        historyMaxCount = executepscommand.RunExternalPSCommandCommand.PoSh_HISTORY_MAX_LENGTH
        newCommands = [str(x) for x in range(historyMaxCount)]

        map(self.command._addToPSHistory, newCommands)

        actual = newCommands[0]

        lastCommand = self.command.PSHistory[0]
        self.command._addToPSHistory("NEW_COMMAND")

        self.assertNotEquals(lastCommand, self.command.PSHistory[0])


if __name__ == "__main__":
    unittest.main()