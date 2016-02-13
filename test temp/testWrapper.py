__author__ = 'kakit'

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

# step_cal = 12.7
# t_start = time()
# step_list = cs.gen_step_list(0,0,1,-9.77,step_cal)
# t_end = time()
#
# ab_pos_list = [[0, 0]]
# for ab in step_list:
#     ab_pos_list.append([ab_pos_list[-1][0] + ab[0], ab_pos_list[-1][1] + ab[1]])
# xy_pos_list = [[(a+b)/2., (a-b)/2.] for [a,b] in ab_pos_list]
#
# for [x,y] in xy_pos_list:
#     print x / step_cal, ",", y / step_cal
#
# print t_end - t_start, "seconds"

test2 = cs.TestClass()