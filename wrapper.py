__author__ = 'kakit'


# import cgpioTest as cg
#
# cg.gpioInit()
# cg.freqTest()
# cg.jitterTest()
# cg.gpioClose()

#Compile everything
import os
os.system("build.bat")

#test
import hardwareDriver as hd
hd.laser_cut(0,0,0)