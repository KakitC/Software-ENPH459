"""
gcodeInterface.pyx
An interface for converting all G-code style commands and raw G-code into laser
cutter hardware actions.

G-code commands from reprap.org/wiki/G-code
and https://en.wikipedia.org/wiki/G-code
"""
__author__ = 'kakit'

from HardwareManager import HardwareManager

class GcodeInterface(HardwareManager):
    """ An interface layer on top of the base HardwareManager which implements
    a G-code style interface in terms of the hardware access functions.
    """
    def __init__(self):
        # super(self.__class__, self).__init__(self)  # super doesn't work
        HardwareManager.__init__(self)
        self.relative = False
        self.las_on = False


    def G0(self, x, y, f=-1):
        """ G0: Rapid move.

        Does not fire laser, otherwise identical to G1

        :param x: X value
        :param y: Y value
        :param f: New feedrate in mm/min (Optional)
        :return: void
        """
        if f > 0:
            self.set_speed(self.cut_spd, f/60.)

        x_delta, y_delta = x, y
        if not self.relative:
            x_delta -= self.x
            y_delta -= self.y

        self.laser_cut(x_delta, y_delta, las_setting="blank")
        # TODO raise exceptions


    def G1(self, x, y, f=-1):
        """ G1: Controlled Move

        If feedrate is given, it will be stored as the travel speed or the
        cutting speed, depending on whether or not the laser is enabled at the
        start of the move/cut.

        :param x: X value
        :param y: Y value
        :param f: New feedrate in mm/min (Optional)
        :return: void
        """
        if f > 0:
            if self.las_on:
                self.set_speed(f/60., self.travel_spd)
            else:
                self.set_speed(self.cut_spd, f/60.)

        x_delta, y_delta = x, y
        if not self.relative:
            x_delta -= self.x
            y_delta -= self.y

        las_setting = "default" if self.las_on else "blank"
        self.laser_cut(x_delta, y_delta, las_setting=las_setting)
        # TODO raise exceptions


    def G20(self):
        """ G20: Set Units to Inches

        NOT IMPLEMENTED

        :return: void
        """
        raise NotImplementedError("G20: Set Units to Inches not implemented")


    def G21(self):
        """ G21: Set Units to mm

        NOT IMPLEMENTED

        :return: void
        """
        raise NotImplementedError("G21: Set Units to mm not implemented")


    def G28(self):
        """ G28: Move to origin (Home)
        :return: void
        """

        if self.home_xy() != 0:
            raise RuntimeError("Homing sequence failed")


    def G90(self):
        """ G90: Set to Absolute Positioning
        :return: void
        """

        self.relative = False


    def G91(self):
        """ G91: Set to Relative Positioning
        :return: void
        """

        self.relative = True


    def G92(self, x=0, y=0):
        """ G92: Set Position

        Sets the current position to the values given without moving.
        If x or y are not specified, they are set to 0.

        :param x: New x position (default 0)
        :type: double
        :param y: New y position (default 0)
        :type: double
        :return: void
        """

        self.x, self.y = x, y


    def M0(self):
        """ M0: Unconditional Stop

        Turns off all motors and laser, then throws exception to quit everything

        :return: void
        """

        self.las_on = False
        self.motor_en_disable(0)
        raise SystemExit("M0: Unconditional Stop called")


    def M1(self):
        """ M1: Sleep

        Turns off all motors and laser.

        :return: void
        """

        self.las_on = False
        self.motor_en_disable(0)


    def M3(self, s):
        """ M3: Spindle On (Laser On)

        Adapted from standard G-code M3: Spindle On at S(RPM).
        Currently sets laser power to on or off, no in-between.
        Laser only fires while moving with G1.

        :param s: Laser power
        :type: int
        :return: void
        """

        self.las_on = True if s else False


    def M5(self):
        """ M5: Spindle Off (Laser Off)

        Turns the laser off.

        :return: void
        """

        self.las_on = False


    def M17(self):
        """ M17: Enable All Stepper Motors

        :return: void
        """

        self.motor_en_disable(1)


    def M18(self):
        """ M18: Disable All Stepper Motors

        :return: void
        """

        self.motor_en_disable(0)


    def M42(self, p, s):
        """ M42: Switch I/O Pin

        NOT IMPLEMENTED

        :param p: Which pin to switch (RPi physical numbering)
        :type: int
        :param s: Pin value
        :type: int
        :return: void
        """

        raise NotImplementedError("M42: Switch I/O Pin not implemented")


    def M72(self, p):
        """ M72: Play a Tone or Song

        NOT IMPLEMENTED

        :param p: ID code for which song to play
        :type: int
        :return: void
        """

        raise NotImplementedError("M72: Play a Tone or Song not implemented")


    def M92(self, x=None, y=None):
        """ M92: Set Axis Steps Per Unit

        Sets step_cal X or Y, or just X if both are give

        :param x: steps/mm value
        :type: double
        :param y: steps/mm value
        :type: double
        :return: void
        """

        if x is not None:
            self.step_cal = x
        elif y is not None:
            self.step_cal = y


    def M106(self, p, s):
        """ M106: Fan On

        NOT IMPLEMENTED

        :param p: Fan ID number (default 0)
        :type: int
        :param s: Fan speed (0-255)
        :type: int
        :return: void
        """

        raise NotImplementedError("M106: Fan On not implemented")


    def M107(self):
        """ M107: Fan Off

        NOT IMPLEMENTED

        :return: void
        """

        raise NotImplementedError("M107: Fan Off not implemented")


    def M114(self):
        """ M114: Get Current Position

        :return: Current x and y position values
        :rtype: String
        """

        return "X:{.2f} Y:{.2f}".format(self.x,self.y)


    def M115(self):
        """ M115: Get Firmware Version and Capabilities
        :return: Firmware information
        :rtype: String
        """

        return "V0.1 of Sketch 'n' Etch firmware"


    def M119(self):
        """ M119: Get Endstop Status

        :return: bitwise integer of endstop values (XMIN, XMAX, YMIN, YMAX)(lsb)
        :rtype: int
        """

        return self.read_switches() & 0xf


    # # NOT IMPLEMENTED
    # M203: Set maximum feedrate
    # M206 Marlin, Sprinter, Smoothie, RepRapFirmware - Set home offset
    # M208: Set axis max travel
    # M240: Trigger camera
    # M300: Play beep sound
    # M500: Store parameters in EEPROM
    # M501: Read parameters from EEPROM
    # M502: Revert to the default "factory settings."
    # M503: Print settings
    # M550: Set Name
    # M552: Set IP address
    # M553: Set Netmask