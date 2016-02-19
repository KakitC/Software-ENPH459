"""
wrapper.py
Debugging script for testing
"""
__author__ = 'kakit'

import PIL
import numpy as np
import math
import time

import platform
import os
from time import time

OS = platform.system()
if OS == "Windows":
    print "WARNING: This will not work in Windows"
    #os.system("build.bat")
else:
    os.system("sh build.sh")
    os.nice(-20)

import HardwareManager as HM
import hardwareDriver as hd

hman = HM.HardwareManager()



print "cut", hman.laser_cut(1, 10, 1, 1)
print "home", hman.home_xy()
print "cut", hman.laser_cut(1, 10, 1, 1)

hman.set_step_cal(100)
tstart = time()
hman.laser_cut(1, 1, 10, 1, "dark")
tend = time()
print tend - tstart