"""
HManHelper.pyx

"""
__author__ = 'kakit'

import hardwareDriver as hd

cpdef laser_cut(self, double x_delta, double y_delta,
              las_setting="default"):
    """ Perform a single straight-line motion of the laser head
    while firing the laser according to the mask image.

    Requires gpio_init to be ran first.
    Laser moves at cut_spd when laser is on, travel_spd else. If speeds are
    not specified, it will use the default values or the last used speeds.
    Uses image bitmap from las_mask as the masking bits, or quick options
    from las_setting.

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
    # 5. Main movement loop, iterate on lists
    # 5a. Step X,Y, set las
    # 5b. Poll switches
    #       if switches: Fail out, throw that exception
    # 5c. Timing idle until next timing delta on list is passed
    # 6. cleanup, return

    # Check if hardware was initialized
    if not self.homed or not self.motors_enabled:
        return -1

    # Moved cutting speed code to GcodeManager
    # # Store speed values as last used
    # if cut_spd > 0:
    #     self.cut_spd = cut_spd
    # if travel_spd > 0:
    #     self.travel_spd = travel_spd

    # TODO Check command against soft XY limits
    # TODO Check speed against max toggle rate (~<1kHz) and limit
    # Convert to A,B pixels delta
    cdef int a_delta = int(round((x_delta + y_delta) * self.step_cal))
    cdef int b_delta = int(round((x_delta - y_delta) * self.step_cal))

    # TODO Check against a 0 distance move
    if a_delta == 0 and b_delta == 0:
        return 0

    # Create step list, lasing list, timing list
    step_list = self._gen_step_list(a_delta, b_delta)
    las_list = self._gen_las_list(step_list, setting=las_setting)
    time_list = self._gen_time_list(self.cut_spd, self.travel_spd, las_list)

    # TODO break up command into multiple cuts so OS can schedule interrupts
    # Move laser head, with precise timings
    retval = hd.move_laser(step_list, las_list, time_list)
    if retval != 0:
        return retval
    # TODO raise exceptions: end stop trigger, safety switch trigger
    # TODO What levels of functions should raise exceptions or error codes?
    # Currently using: low-level returns non-zero vals, high level raise


    # Update position tracking
    # TODO track error in x and y delta and do something about it
    # self.x += 0.5*(a_delta + b_delta) / self.step_cal
    # self.y += 0.5*(a_delta - b_delta) / self.step_cal
    self.x += x_delta
    self.y += y_delta

    return 0

############################# INTERNAL FUNCTIONS ############################
def _gen_step_list(self, int a_delta, int b_delta):
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
    # TODO Optimize step_list gen by using C arrays
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


def _gen_las_list(self, step_list, setting="default"):
    """ Create a list of 1-bit laser power (on/off) for cutting path.

    Has options for generating stock las_list's quickly. Currently supports:
    "blank" - All white, no cut
    "dark" - All black, cut everything

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

    cdef double x_now = self.x
    cdef double y_now = self.y
    cdef int mask_xsize = len(self.las_mask)
    cdef int mask_ysize = len(self.las_mask[0])
    cdef int x_px, y_px

    las_list = []

    for i in step_list:
        x_now += 0.5*(i[0] + i[1]) * self.step_cal
        y_now += 0.5*(i[0] - i[1]) * self.step_cal

        # Sets laser power to 0 if mask is 255 (blank = don't cut)
        # TODO account for out-of-bounds errors
        x_px = int(x_now * self.las_dpi)
        y_px = int(y_now * self.las_dpi)

        las_list.append(1 if self.las_mask[x_px][y_px] != 255 else 0)

    return las_list


def _gen_time_list(self, cut_spd, travel_spd, las_list):
    """ Create a list of times to stay at each step for laser cutting
    or moving.

    :param las_list: laser cutting bit list
    :type: list[n] of 0 or 1
    :return: List of times
    :rtype: list[n] <integer>
    """

    # TODO do 8 bit timings
    # TODO account for diagonal travel being faster than orthogonal
    return [int(hd.USEC_PER_SEC / (cut_spd * self.step_cal)) if i
            else int(hd.USEC_PER_SEC / (travel_spd * self.step_cal))
            for i in las_list]