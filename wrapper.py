__author__ = 'kakit'


# import cgpioTest as cg
#
# cg.gpioInit()
# cg.freqTest()
# cg.jitterTest()
# cg.gpioClose()

import platform
OS = platform.system()

import os

# if OS == "Windows":
#     os.system("build.bat")
# else:
#     os.system("sh build.sh")
#     os.nice(-20)
os.nice(-20)

#test
#import arrayTest


import hardwareDriver as hd
testlen = 1000
testperiod = 1000
step_listA = [1 for _ in range(testlen)]
step_listB = [1 for _ in range(testlen)]
las_list = [x % 2 for x in range(testlen)]
time_list = [testperiod for _ in range(testlen)]

hd.gpio_init()
for i in range(3):
    hd.move_laser_wrapper(step_listA, step_listB, las_list, time_list)
