__author__ = 'kakit'

import platform
import os
from HardwareManager import HardwareManager
from time import time

OS = platform.system()
# if OS == "Windows":
#     os.system("build.bat")
# else:
#     os.system("sh build.sh")
#     os.nice(-20)
os.nice(-20)


#import hardwareDriver as hd
# testlen = 1000
# testperiod = 1000
# step_listA = [1 for _ in range(testlen)]
# step_listB = [1 for _ in range(testlen)]
# las_list = [x % 2 for x in range(testlen)]
# time_list = [testperiod for _ in range(testlen)]
#
# hd.gpio_init()
# for i in range(3):
#     hd.move_laser_wrapper(step_listA, step_listB, las_list, time_list)

HWMan = HardwareManager()
print "cut", HWMan.laser_cut(1,10,1,1)
print "home", HWMan.home_xy()
print "cut", HWMan.laser_cut(1,10,1,1)

HWMan.set_step_cal(100)
tstart = time()
HWMan.laser_cut(1,1,10,1, "dark")
tend = time()
print tend - tstart