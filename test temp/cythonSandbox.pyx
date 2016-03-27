"""
cythonSandbox.pyx
Test Cython file for checking Cython syntax in Windows without needing to
build Linux libraries
"""
from cpython cimport array
# import array
#
# cdef array.array a = array.array('i', [i for i in range(5)])
# cdef array.array b = array.array('i', [i for i in range(5)])
# for i in range(5):
#     print a.data.as_ints[i]
#     print b.data.as_ints[i]

from math import *
USEC_PER_SEC = 1000000
############################# INTERNAL FUNCTIONS ############################
cpdef _gen_step_list(int a_delta, int b_delta):
    """ Create a list of A/B steps from X/Y coordinates and step size.

    Uses Bresenhem line rasterization algorithm.

    :param a_delta: Number of steps to take on A axis
    :type: int
    :param b_delta: Number of steps to take on B axis
    :type: int
    :return: list of A/B steps (+/- 1 or 0)
    :rtype: list[n][2]
    """

    # Divide into quadrants by reversing directions as needed
    cdef bint a_flip_flag = False
    cdef bint b_flip_flag = False
    cdef bint ab_flip_flag = False

    if a_delta < 0:
        a_delta = -a_delta
        a_flip_flag = True
    if b_delta < 0:
        b_delta = -b_delta
        b_flip_flag = True

    # Divide into octants by swapping so A > B
    if b_delta > a_delta:
        a_delta, b_delta = b_delta, a_delta # yep, that's safe /s
        ab_flip_flag = True

    # Generate step list for line in first octant. Bresenham's algo here
    # TODO Optimize gen_step_list by using C arrays
    step_list = []
    cdef int a_now = 0
    cdef int error = 2*b_delta - a_delta
    while a_now < a_delta:
        a_now += 1
        ab_list = [1,0]
        error += 2*b_delta
        if error >= 0:
            ab_list[1] = 1
            error -= 2*a_delta
        step_list.append(ab_list)

    # Reverse octants, quadrants
    if ab_flip_flag:
        step_list = [[_[1], _[0]] for _ in step_list]

    if a_flip_flag:
        step_list = [[-_[0], _[1]] for _ in step_list]
    if b_flip_flag:
        step_list = [[_[0], -_[1]] for _ in step_list]

    return step_list


cpdef _gen_las_list(hman, step_list, setting="default"):
    """ Create a list of 1-bit laser power (on/off) for cutting path.

    Has options for generating stock las_list's quickly. Currently supports:
    "blank" - All white, no cut
    "dark" - All black, cut everything
    "default" - Compares projected position against laser darkfield bitmask

    :param step_list: List of A/B steps to take for cut operation
    :type: list[n][2] of int(+/-1 or 0)
    :param setting: las_list generation settings.
    :return: laser cutting bit list
    :rtype: list[n] of [0 or 1]
    """

    if setting == "blank":
        return [0 for i in range(len(step_list))]
    if setting == "dark":
        return [1 for i in range(len(step_list))]

    cdef double x_now = hman.x
    cdef double y_now = hman.y
    # cdef int mask_xsize = len(hman.las_mask)
    # cdef int mask_ysize = len(hman.las_mask[0])
    cdef int mask_xsize = hman.las_mask.shape[0]
    cdef int mask_ysize = hman.las_mask.shape[1]
    cdef int x_px, y_px
    # TODO Cast las_mask as a C array for speed and compatibility
    # las_mask currently a numpy array

    las_list = []

    for i in step_list:
        x_now += 0.5*(i[0] + i[1]) / hman.step_cal
        y_now += 0.5*(i[0] - i[1]) / hman.step_cal

        # Sets laser power to 0 if mask is 255 (blank = don't cut)
        x_px = int(x_now * hman.las_dpmm)
        y_px = int(y_now * hman.las_dpmm)

        # TODO account for out-of-bounds errors
        if x_px >= hman.las_mask.shape[1] or y_px >= hman.las_mask.shape[0]:
            las_list.append(0)
            continue

        las_list.append(1 if hman.las_mask[y_px][x_px] != 255 else 0)
        # las_list.append(255-hman.las_mask[x_px][y_px]) # 8b power settings
        # TODO do 8 bit laser power settings and gamma curve

    return las_list



cpdef _gen_time_list(hman, las_list):
    """ Create a list of times to stay at each step for laser cutting
    or moving.

    :param las_list: laser cutting bit list
    :type: list[n] of 0 or 1
    :return: List of times
    :rtype: list[n] <integer>
    """

    # TODO do 8 bit timings
    # TODO account for diagonal travel being faster than orthogonal
    return [int(USEC_PER_SEC / (hman.cut_spd * hman.step_cal)) if i
            else int(USEC_PER_SEC / (hman.travel_spd * hman.step_cal))
            for i in las_list]