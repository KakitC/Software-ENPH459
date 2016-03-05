"""
HardwareManager.pyx
The HardwareManager object class, for maintaining laser cutter state and
control and setting interfaces
"""

__author__ = 'kakit'

import hardwareDriver as hd
import HManHelper as HMH


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
        self.travel_spd = 30  # mm/s
        self.las_mask = [[255]]  # 255: White - PIL Image 0-255 vals
        self.las_dpi = 0.00001  # ~0 DPI, 1 pixel for whole space
        self.bed_xmax = 200  #
        self.bed_ymax = 250

        # Vals on init
        self.homed = False
        self.motors_enabled = False
        self.x, self.y = 0.0, 0.0
        if hd.gpio_init() != 0:
            raise IOError("GPIO not initialized correctly")

    def __del__(self):
        # TODO document this
        # TODO check this works/ is good enough
        self.mots_en(0)
        hd.gpio_close()

################### SETTINGS INTERFACE FUNCTIONS #####################

    def set_las_mask(self, filepath, scale):
        """ Set laser bit mask to an image on disk, stretched to scale

        :param filepath: Linux image full filepath and name
        :type: string
        :param scale: DPI of the image
        :type: double
        :return: void
        """
        self.las_mask = filepath # TODO REMOVE HACK
        self.las_dpi = scale


    def set_step_cal(self, step_cal):
        """ Changes the steps/mm setting of the stepper motors
        :param step_cal: steps per mm
        :type: double
        :return: void
        """
        self.step_cal = step_cal


    def set_spd(self, cut_spd, travel_spd):
        """ Sets the default speed of the laser head for if it is not specified
        during the moving operation.

        :param cut_spd: Laser speed while cutting in mm/s
        :type: double
        :param travel_spd: Moving speed if not cutting in mm/s
        :type: double
        :return: void
        """

        self.cut_spd = cut_spd
        self.travel_spd = travel_spd


#################### HW INTERFACE FUNCTIONS ########################

    def home_xy(self):
        """ Initialize laser position by moving to endstop min position (0,0).
        :return: 0 if successful, -1 if an error occured
        """
        if not self.motors_enabled:
            self.mots_en(1)

        # TODO put in homing routine
        # Move XY to -bedmax, until an switch is triggered
        # If it's safety feet, stop
        # If it's either, move it back out (ignoring endstops here), then back
        # If it's both, move them back out, then individually back in
        # TODO Figure out how to ignore endstops for homing

        self.x, self.y = 0, 0
        self.homed = True

        return 0


    def las_test(self, time):
        """ Pulse laser output for testing purposes.

        This is a wrapper for a hardwareDriver function.

        :param time: Pulse time in seconds
        :type: double
        :return: void/null
        """

        hd.las_pulse(time)


    def read_switches(self):
        """ Read values of XY endstop switches and safety feet.

        This is a wrapper for a hardwareDriver function.

        :return: Bitwise 5-bit value for XMIN, XMAX, YMIN, YMAX, SAFE_FEET (LSB)
                (i.e. 0b01001 => 9: YMAX, XMIN)
        :rtype: int
        """

        return hd.read_switches()


    def mots_en(self, en):
        """ Enable or disable stepper motors.

        This is a wrapper for a hardwareDriver function.

        :param en: 1 to enable, 0 to disable
        :type: bint (bool)
        :return: void
        """

        if en:
            hd.motor_enable()
            self.motors_enabled = True
        else:
            hd.motor_disable()
            self.motors_enabled = False
            self.homed = False


    def laser_cut(self, x_delta, y_delta, las_setting="default"):
        """ Perform a single straight-line motion of the laser head
        while firing the laser according to the mask image.

        This is a wrapper for the HManHelper function of the same name.

        :param x_delta:
        :param y_delta:
        :param las_setting:

        :return:
        """

        return HMH.laser_cut(self, x_delta, y_delta, las_setting)
