__author__ = 'kakit'

import hardwareDriver as hd

class HardwareManager:
    """ An object to track all laser cutter hardware state information and
    settings, and presents the hardware control and sensor interfaces.

    Uses hardwareDriver functions to do the actual GPIO accesses, but
    otherwise implements the control and sensor interface functions.
    """

    cpdef __init__(self):
        """ Instantiate and initialize default settings for HardwareManager.
        """
        self.x, self.y = 0, 0
        self.step_cal = 12.7
        self.cut_spd = 10
        self.travel_spd = 100
        self.homed = False
        self.motors_enabled = False
        if hd.gpio_init() != 0:
            raise IOError("GPIO not initialized correctly")

############### HW INTERFACE FUNCTIONS ########################

    cpdef home_xy(self):
        """ Initialize laser position by moving to endstop min position (0,0).
        """
        hd.motor_enable()
        self.motors_enabled = True

        # TODO put in homing routine
        self.x, self.y = 0, 0
        self.homed = True

        return 0


    cpdef set_las_mask(self, filepath, scale):
        """ Set laser bit mask to an image on disk, stretched to scale

        :param filepath: Linux image full filepath and name
        :type: string
        :param scale: PPI of the image
        :type: int
        :return: void
        """
        pass


    cpdef laser_cut(self, double cut_spd, double travel_spd,
                    double x_delta, double y_delta):
        """ Perform a single straight-line motion of the laser head
        while firing the laser according to the mask image.

        Laser moves at cut_spd when laser is on, travel_spd else.
        Uses image bitmap from las_mask. Requires gpio_init to be ran first.

        :param cut_spd: Cutting speed in mm/s
        :type: double
        :param travel_spd: Travel speed in mm/s
        :type: double
        :param x_delta: X position change in mm
        :type: double
        :param y_delta: Y position change in mm
        :type: double
        """

        # TODO Implement laser_cut()
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
        #       # This can just be polled, min speed might be 1mm/s but still
        #       # stepping at 75ms period (13Hz)
        # 5c. Timing idle until next timing delta on list is passed
        # 6. cleanup, return

        # 1. Create pathing step list
        # 1a. Make pixelized line from (x_start,y_start) to (x_end,y_end)
        if not self.homed or not self.motors_enabled:
            return -1

        # Convert to A,B pixels delta
        cdef int a_delta = int(round((x_delta + y_delta) * self.step_cal))
        cdef int b_delta = int(round((x_delta - y_delta) * self.step_cal))
        # TODO track error in x and y delta

        step_list = self._gen_step_list(a_delta, b_delta)

        return 0
        #TODO exceptions: end stop trigger, safety switch trigger

############################# INTERNAL FUNCTIONS ############################
    cdef _gen_step_list(self, int a_delta, int b_delta):
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
        # TODO Optimize step_list gen by using C arrays?
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