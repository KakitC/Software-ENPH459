"""
HManHelper.pyx
A collection of Cython accelerated functions for use by the HardwareManager
class. Primarily for the laser control algorithm.
"""
from __future__ import division

cimport hardwareDriver as hd
cimport numpy as np

cpdef laser_cut(hman, double x_delta, double y_delta,
                las_setting="default"):
    """ Perform a single straight-line motion of the laser head
    while firing the laser according to the mask image.

    Requires gpio_init to be ran first.
    Laser moves at cut_spd when laser is on, travel_spd else. If speeds are
    not specified, it will use the default values or the last used speeds.
    Uses image bitmap from las_mask as the masking bits, or quick options
    from las_setting.

    :param hman: Hardware Manager object
    :type: HardwareManager
    :param x_delta: X position change in mm
    :type: double
    :param y_delta: Y position change in mm
    :type: double
    :param las_setting: _gen_las_list quick options
    :type: string
    """

    # Algorithm:
    # 1. Create pathing step list
    # 1a. Make pixelized line from (x_start,y_start) to (x_end,y_end)
    # 1b. Convert line into a list of A,B coordinates (algo)
    # 2. Create laser spot list from pathing step position vs image
    # 3. Create timing list from speeds and laser spot list
    # 4. Initialize and check things, clear interrupts?
    # 5. Main movement loop, iterate on lists (in hardwareDriver.pyx)
    #   5a. Step X,Y, set las
    #   5b. Poll switches
    #       if switches: Fail out, return switches as error code
    #   5c. Timing idle until next timing delta on list is passed
    # 6. cleanup, return

    # Check if hardware was initialized
    if not hman.homed or not hman.mots_enabled:
        return -1

    # Moved cutting speed code to GcodeManager
    # # Store speed values as last used
    # if cut_spd > 0:
    #     hman.cut_spd = cut_spd
    # if travel_spd > 0:
    #     hman.travel_spd = travel_spd

    # TODO Check command against soft XY limits
    # TODO Check speed against max toggle rate (~<1kHz) and limit
    # TODO Implement separate X/Y or A/B step_cal values
    # Convert to A,B pixels delta
    cdef int a_delta = int(round((x_delta + y_delta) * hman.step_cal))
    cdef int b_delta = int(round((x_delta - y_delta) * hman.step_cal))

    if a_delta == 0 and b_delta == 0:  # this kind of works
        return 0

    # Create step list, lasing list, timing list
    step_list = _gen_step_list(a_delta, b_delta)
    las_list = _gen_las_list(hman, step_list, setting=las_setting)
    time_list = _gen_time_list(hman, las_list)

    # TODO break up command into multiple cuts so OS can schedule interrupts?
    # Move laser head, with precise timings
    retval = hd.move_laser(step_list, las_list, time_list)
    if retval != 0:
        # TODO Track current position if interrupted by switch
        return retval

    # Update position tracking
    hman.x += 0.5*(a_delta + b_delta) / hman.step_cal
    hman.y += 0.5*(a_delta - b_delta) / hman.step_cal

    return 0


cpdef home_xy(hman):
    if not hman.mots_enabled:
        hman.mots_en(1)

    hman.homed = True

    hman.set_spd(travel_spd=100)

    # Move XY to -bedmax, until an switch is triggered
    # If it's safety feet, stop
    # If it's either, move it back out (ignoring endstops here)
    x_flag, y_flag = 1, 1

    while x_flag or y_flag:
        status = hman.laser_cut(-x_flag * hman.bed_xmax,
                                -y_flag * hman.bed_ymax, "blank")
        # print "status", status  # debug
        if status == 0 or (status & (0x1 << hd.SAFE_FEET)):
            # If no endstops triggered after the move or safety is engaged
            hman.homed = False
            return -1
        elif status & (0x1 << hd.YMAX + 0x1 << hd.XMAX):
            hman.homed = False
            return -1

        # If hit minstop, use while to back away and override switch
        # TODO Test how repeatable this is
        if status & (0x1 << hd.YMIN):
            # Back off, move in slowly, then back off again
            hman.set_spd(travel_spd=3)
            while hman.laser_cut(0, 1, "blank") & (0x1 << hd.YMIN):
                pass
            hman.laser_cut(0,-1, "blank")  # TODO What if both endstops are hit?
            while hman.laser_cut(0, 1, "blank") & (0x1 << hd.YMIN):
                pass

            hman.set_spd(travel_spd=100)
            y_flag = 0

        if status & (0x1 << hd.XMIN):
            hman.set_spd(travel_spd=3)
            while hman.laser_cut(1, 0, "blank") (0x1 << hd.XMIN):
                pass
            hman.laser_cut(-1,0, "blank")
            while hman.laser_cut(1, 0, "blank") (0x1 << hd.XMIN):
                pass

            hman.set_spd(travel_spd=100)
            x_flag = 0

    hman.x, hman.y = 0, 0

    return 0


############################# INTERNAL FUNCTIONS ############################
cdef _gen_step_list(int a_delta, int b_delta):
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


cdef _gen_las_list(hman, step_list, setting="default"):
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
    else:
        # TODO finish implementing this properly
        print "gen_las_list not verified, not cutting"
        return [0 for i in range(len(step_list))]

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
        x_now += 0.5*(i[0] + i[1]) * hman.step_cal
        y_now += 0.5*(i[0] - i[1]) * hman.step_cal

        # Sets laser power to 0 if mask is 255 (blank = don't cut)
        # TODO account for out-of-bounds errors
        # should actually be
        x_px = int(x_now * hman.las_dpi)
        y_px = int(y_now * hman.las_dpi)

        if x_px >= hman.las_mask.shape[0] or y_px >= hman.las_mask.shape[1]:
            las_list.append(0)
            continue

        las_list.append(1 if hman.las_mask[x_px][y_px] != 255 else 0)
        # las_list.append(hman.las_mask[x_px][y_px]) # 8b power settings
        # TODO do 8 bit laser power settings and gamma curve

    return las_list


cdef _gen_time_list(hman, las_list):
    """ Create a list of times to stay at each step for laser cutting
    or moving.

    :param las_list: laser cutting bit list
    :type: list[n] of 0 or 1
    :return: List of times
    :rtype: list[n] <integer>
    """

    # TODO do 8 bit timings
    # TODO account for diagonal travel being faster than orthogonal
    return [int(hd.USEC_PER_SEC / (hman.cut_spd * hman.step_cal)) if i
            else int(hd.USEC_PER_SEC / (hman.travel_spd * hman.step_cal))
            for i in las_list]