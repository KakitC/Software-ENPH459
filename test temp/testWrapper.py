"""
testWrapper.py
Test script for cythonSandbox
"""

import platform
OS = platform.system()

import os

if OS == "Windows":
    os.system("build.bat")
    from time import clock as time
else:
    os.system("sh build.sh")
    from time import time
    os.nice(-20)


import cythonSandbox as cs
cs.testfun()
print cs.d
print cs.x