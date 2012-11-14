import os
import sys

THIS_FILE_DIR = os.path.abspath(os.path.split(__file__)[0])
PATH_TO_MODULE_TO_TEST = os.path.abspath( os.path.join(THIS_FILE_DIR, "..") )
sys.path = [PATH_TO_MODULE_TO_TEST] + sys.path
