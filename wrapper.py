__author__ = 'kakit'


# import cgpioTest as cg
#
# cg.gpioInit()
# cg.freqTest()
# cg.jitterTest()
# cg.gpioClose()

import platform
OS = platform.system()

#Compile everything
import os
if OS == "Windows":
    os.system("build.bat")
else:
    os.system("sh build.sh")

#test
#import arrayTest


import hardwareDriver as hd
step_listA = [1 for _ in range(1000)]
step_listB = [1 for _ in range(1000)]
las_list = [x%2 for x in range(1000)]
time_list = [1000 for _ in range(1000)]
hd.move_laser_wrapper(step_listA, step_listB, las_list, time_list)