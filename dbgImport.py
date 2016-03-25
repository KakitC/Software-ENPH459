"""
debugImport.py
This file is for setting up all the imports at the beginning
of an interactive debug session in the Python console.
To use, type: execfile("debugImport.py")
"""

import PIL
import numpy as np
import math
import time

import platform
import os
# from time import time

OS = platform.system()
if OS == "Windows":
    print "WARNING: This will not work in Windows"
    #os.system("build.bat")
else:
    print "Recompiling..."
    os.system("sh build.sh")
    os.nice(-20)

import HardwareManager as HM
import hardwareDriver as hd
import GcodeInterface as GI
import ipsRaster as ipsR
import scanBlock as scn


gman = GI.GcodeInterface()