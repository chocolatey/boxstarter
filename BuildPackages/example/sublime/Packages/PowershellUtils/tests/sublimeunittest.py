import sys
import os

# TODO: paths are hardcoded!
THIS_FILE_DIR = os.path.abspath(os.path.split(__file__)[0])
PATH_TO_MODULE_TO_TEST = os.path.abspath(os.path.join(THIS_FILE_DIR, ".."))
RELEASE_PATH = os.path.abspath(os.path.join(os.path.split(__file__)[0], "../../SublimePluginTesting/sublimemocks"))
DEV_PATH = os.path.abspath(os.path.join(os.path.split(__file__)[0], "../../XXXSublimePluginTesting/sublimemocks"))
DEBUG = os.path.exists(DEV_PATH)
PATH_TO_SUBLIMETEXT_TEST_FRAMEWORK = DEV_PATH if DEBUG else RELEASE_PATH


class SublimeTextUnitTestError(Exception):
    pass


if not os.path.exists(PATH_TO_SUBLIMETEXT_TEST_FRAMEWORK):
    raise SublimeTextUnitTestError("Cannot find path to test framework (is it installed?).")

sys.path = [PATH_TO_MODULE_TO_TEST, PATH_TO_SUBLIMETEXT_TEST_FRAMEWORK] + sys.path
