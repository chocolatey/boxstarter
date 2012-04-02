
import _setuptestenv
import sys

try:
    import mock
except ImportError:
    print "ERROR: Cannot find mock module in your SYSTEM'S Python library."
    sys.exit(1)

import unittest
import sublime
import sublimeplugin

#===============================================================================
# Add your tests below here.
#===============================================================================

import sublimepath

class RootAtPackagesDirFunction(unittest.TestCase):

    def testCallWithoutArguments(self):
        actual = sublimepath.rootAtPackagesDir()
        self.assertEquals(actual, "?????")

    def testCallWithOneArgument(self):
        actual = sublimepath.rootAtPackagesDir("XXX")
        self.assertEquals(actual, "?????\\XXX")

    def testCallWithMultipleArguments(self):
        actual = sublimepath.rootAtPackagesDir("XXX", "YYY")
        self.assertEquals(actual, "?????\\XXX\\YYY")


if __name__ == "__main__":
    unittest.main()
