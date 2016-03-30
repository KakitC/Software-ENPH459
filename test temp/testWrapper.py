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
import numpy as np
from PIL import Image


class HardwareManager(object):
    """ An object to track all laser cutter hardware state information and
    settings, and presents the hardware control and sensor interfaces.

    Uses hardwareDriver functions to do the actual GPIO accesses, but
    otherwise implements the control and sensor interface functions.
    Only one HardwareManager should exist per laser cutter, or else GPIO
    access conflicts will occur, among other errors.
    """


    def __init__(self):
        """ Instantiate and initialize default settings for HardwareManager.
        """

        # Default vals and settings
        self.step_cal = 10  # steps/mm
        self.cut_spd = 1  # mm/s
        self.travel_spd = 100  # mm/s
        self.bed_xmax = 250  # mm
        self.bed_ymax = 280  # mm
        self.skew = 0  # degrees

        self.las_mask = np.array([[255]])  # 255: White - PIL Image 0-255 vals
        self.las_dpmm = 0.00000001  # ~0 Dots Per mm, 1 pixel for whole space

        # Vals on init
        self.homed = False
        self.mots_enabled = False
        self.x, self.y = 0.0, 0.0


hman = HardwareManager()
pic = Image.open('raster_cal4.png')
pic = pic.convert("L")
pic = pic.convert("1")
print "histogram", pic.histogram()[0], pic.histogram()[-1]
pic.save("raster_cal4_out.png")
pic = pic.convert("L")
hman.las_mask = np.array(pic)
hman.las_dpmm = 10

x_delta, y_delta = .06,.99
a_delta = int(round((x_delta + y_delta) * hman.step_cal))
b_delta = int(round((x_delta - y_delta) * hman.step_cal))
step_list = cs._gen_step_list(a_delta,b_delta)
las_list = cs._gen_las_list(hman, step_list)
time_list = cs._gen_time_list(hman, las_list)
x,y = [],[]
x_now,y_now = hman.x, hman.y
for i in step_list:
    x_now += 0.5*(i[0] + i[1]) / hman.step_cal
    y_now += 0.5*(i[0] - i[1]) / hman.step_cal
    x.append(x_now)
    y.append(y_now)

# Update position tracking
hman.x += 0.5*(a_delta + b_delta) / hman.step_cal
hman.y += 0.5*(a_delta - b_delta) / hman.step_cal

r1 = 0
r2 = -1#r1+10
print "x, y delta", x_delta, y_delta
print "a, b delta", a_delta, b_delta
print "list length", len(step_list)
print "step_list", step_list[r1:r2]
print "Position", zip(x,y)[r1:r2]
print "hman new x, y", hman.x, hman.y
print "real position", zip(x,y)[-1]
print "len of pos list", len(x)
#print "las_list", las_list[r1:r2]
#print "time_list", time_list[r1:r2]