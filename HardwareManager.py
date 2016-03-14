"""
HardwareManager.pyx
The HardwareManager object class, for maintaining laser cutter state and
control and setting interfaces
"""

from __future__ import division

import numpy as np

import HManHelper as HMH
import hardwareDriver as hd


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
        self.las_mask = np.array([[255]])  # 255: White - PIL Image 0-255 vals
        self.las_dpi = 0.00000001  # ~0 DPI, 1 pixel for whole space
        self.bed_xmax = 200  #
        self.bed_ymax = 250

        # Vals on init
        self.homed = False
        self.mots_enabled = False
        self.x, self.y = 0.0, 0.0
        if hd.gpio_init() != 0:
            raise IOError("GPIO not initialized correctly; Do you have root?")


    def __del__(self):
        """ Disable the laser upon quitting, and close the GPIO access.
        """
        # TODO check this works/ is good enough
        self.mots_en(0)
        hd.gpio_close()


    ################### SETTINGS INTERFACE FUNCTIONS #####################

    def set_las_mask(self, img, scale):
        """ Set laser bit mask to an image, stretched to scale

        :param img: Laser bitmask, 0
        :type: PIL.Image.Image
        :param scale: DPI of the image
        :type: double
        :return: void
        """
        self.las_mask = np.array(img)
        # Workaround for numpy not liking "1" mode images
        # self.las_mask = np.array(list(img.getdata())).reshape(img.size)
        self.las_dpi = scale


    def set_step_cal(self, step_cal):
        """ Changes the steps/mm setting of the stepper motors
        :param step_cal: steps per mm
        :type: double
        :return: void
        """
        self.step_cal = step_cal


    def set_spd(self, cut_spd=0, travel_spd=0):
        """ Set the speed of the laser head for if it is not specified
        during the move operation. Specify which speed to modify

        :param cut_spd: Laser speed while cutting in mm/s
        :type: double
        :param travel_spd: Moving speed if not cutting in mm/s
        :type: double
        :return: void
        """

        self.cut_spd = cut_spd if cut_spd != 0 else self.cut_spd
        self.travel_spd = travel_spd if travel_spd != 0 else self.travel_spd


    #################### HW INTERFACE FUNCTIONS ########################

    def home_xy(self):
        """ Initialize laser position by moving to endstop min position (0,0).

        This is a wrapper for the HManHelper function.

        :return: 0 if successful, -1 if an error occured
        """
        return HMH.home_xy(self)


    def las_test(self, time):
        """ Pulse laser output for testing purposes.

        This is a wrapper for a hardwareDriver function.

        :param time: Pulse time in seconds
        :type: double
        :return: void/null
        """

        hd.las_pulse(time)


    def read_sws(self):
        """ Read values of XY endstop switches and safety feet.

        This is a wrapper for a hardwareDriver function.

        :return: Bitwise 5-bit value for XMIN, XMAX, YMIN, YMAX, SAFE_FEET (LSB)
                (i.e. 0b01001 => 9: YMAX, XMIN)
        :rtype: int
        """

        return hd.read_switches()


    def mots_en(self, en):
        """ Enable or disable stepper motors.

        This is mostly a wrapper for a hardwareDriver function.

        :param en: 1 to enable, 0 to disable
        :type: bint (bool)
        :return: void
        """

        if en:
            hd.motor_enable()
            self.mots_enabled = True
        else:
            hd.motor_disable()
            self.mots_enabled = False
            self.homed = False


    def laser_cut(self, x_delta, y_delta, las_setting="default"):
        """ Perform a single straight-line motion of the laser head
        while firing the laser according to the mask image.

        This is a wrapper for the HManHelper function.

        :param x_delta:
        :param y_delta:
        :param las_setting:

        :return:
        """

        return HMH.laser_cut(self, x_delta, y_delta, las_setting)
