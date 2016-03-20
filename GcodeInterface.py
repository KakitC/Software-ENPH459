"""
gcodeInterface.pyx
An interface for converting all G-code style commands and raw G-code into laser
cutter hardware actions.

G-code commands from reprap.org/wiki/G-code
and https://en.wikipedia.org/wiki/G-code
"""

import re
from HardwareManager import HardwareManager

# TODO Implement custom error classes
# HardwareError
#   EstopError
#   Limits error?
# ParseError


class GcodeInterface(HardwareManager):
    """ An interface layer on top of the base HardwareManager which implements
    a G-code style interface in terms of the hardware access functions.
    """

    def __init__(self):
        # super(self.__class__, self).__init__(self)  # super doesn't work
        HardwareManager.__init__(self)
        self.relative = False
        self.las_on = False
        self.cmd_list = [
            "G0 X Y F", "G1 X Y F",  # Move
            # "G20", "G21",  # Set units # not implemented
            "G28",  # Home
            "G90", "G91", "G92 X Y",  # Set abs/rel, position
            "M0", "M1",  # Stop
            "M3 S", "M5",  # las on/off
            "M17", "M18",  # mot en/disable
            # "M42", "M72",  # not implemented
            "M92 X Y",  # Set step cal (mm/min)
            # "M106 P S", "M107",  # fan control # not implemented
            "M114", "M115", "M119"  # diagnostics, return values
        ]


    def __del__(self):
        self.las_on = False
        HardwareManager.__del__(self)


    def parse_gcode(self, filename):
        """ Read gcode from a filepath, and execute the commands.

        Raises IOError if file cannot be opened.

        Raises a SyntaxWarning if there as an issue with the G-code parsing, due
        either to the file being formatted incorrectly or the parser behaving
        unexpectedly.

        Passes along the StandardError sub-exception of some kind if there is an
        issue with executing the commands.

        :param filename: Directory path of the G-code file, absolute or relative
        :type: string
        :return: void, exceptions for errors.
        """

        try:
            infile = open(filename)  # mode 'r'
        except:
            print("Could not open file")
            raise

        lines = infile.readlines()
        execlist = []

        # Gcode parsing rules:
        # Ex: N3 G1 X10.3 Y23.4 *34 ; comment
        #
        # Strip comments
        # Strip any line number (N) fields
        # Strip checksums
        # Parse actual command
        for j, i in enumerate(lines):
            orig_line = i
            i = i.upper()
            i = i[0:i.find(";")]  # strip comments
            i = re.sub(r"N[0-9]*\s", "", i, 1)  # strip line numbers
            try:  # strip checksum [*33]
                ind = i.index("*")
                i = i[0:ind]
            except ValueError:
                pass
            i = i.strip()


            # Parse command into python code
            line = i.split()  # G-code line split list
            if not line:  # No commands in this line
                continue

            execstr = "self."
            for cmd in self.cmd_list:
                cmd = cmd.split()  # cmd is command string split list

                if line[0] == cmd[0]:  # line command is in cmd_list
                    execstr += cmd[0] + "("  # construct direct python call
                    cmd.pop(0)
                    line.pop(0)

                    # Parse command arguements
                    for param in line:  # param: "X123.45"
                        if param[0] in cmd:  # If first char in cmd param list
                            try:  # Check if it's a number
                                float(param[1:])
                            except ValueError:
                                raise SyntaxError("G-code file parsing error: "
                                                  "Command argument not a"
                                                  " number at line" + str(j) +
                                                  ": \n" + orig_line)
                            if execstr[-1] != "(":
                                execstr += ", "
                            execstr += param[0] + "=" + param[1:]
                            cmd.remove(param[0])
                        else:  # Command param not accepted in cmd args
                            raise SyntaxError("G-code file parsing error: "
                                              "Command parameter not accepted"
                                              " at line " + str(j) + ": \n"
                                              + orig_line)

                    execstr += ")"
                    execlist.append(execstr)
                    break  # done making command for this line
            else:  # call not found in cmd_list
                raise SyntaxError("G-code file parsing error: Command not found"
                                  " at line " + str(j) + ": \n" + orig_line)
        # Finished parsing file
        infile.close()

        # TODO should this be changed to execute line by line? Parses whole file
        for execstr in execlist:
            # TODO Catch exceptions and fail correctly
            try:
                # debug
                print(execstr)
                exec(execstr)
            except RuntimeError:
                self.M1()
                raise



################### G code functions ###############################
    """ G0: Rapid move
        G1: Controlled Move
        G20: Set Units to Inches
        G21: Set Units to mm
        G28: Move to origin (Home)
        G90: Set to Absolute Positioning
        G91: Set to Relative Positioning
        G92: Set Position
    """

    def G0(self, X=None, Y=None, F=None):
        """ G0: Rapid move

        Does not fire laser, otherwise identical to G1

        :param x: X value
        :param y: Y value
        :param f: New feedrate in mm/min (Optional)
        :return: void
        """
        if F is not None:
            self.set_spd(travel_spd=F / 60.)

        if X is not None:
            x_delta = X
            if not self.relative:
                x_delta -= self.x
        else:
            x_delta = 0

        if Y is not None:
            y_delta = Y
            if not self.relative:
                y_delta -= self.y
        else:
            y_delta = 0

        retval = self.laser_cut(x_delta, y_delta, las_setting="blank")
        if retval > 0:
            raise RuntimeError("G0 Switch was triggered: " + bin(retval))
        elif retval < 0:
            raise RuntimeError("G0 Laser not homed")


    def G1(self, X=None, Y=None, F=None):
        """ G1: Controlled Move

        If X or Y are not given, the laser will not move on that axis.

        If feedrate is given, it will be stored as the travel speed or the
        cutting speed, depending on whether or not the laser is enabled at the
        start of the move/cut.

        If an endstop is triggered or the safety switches are triggered, a
        RuntimeError exception will be raised.

        :param x: X value
        :param y: Y value
        :param f: New feedrate in mm/min (Optional)
        :return: void
        """
        if F is not None:
            if self.las_on:
                self.set_spd(cut_spd=F / 60.)
            else:
                self.set_spd(travel_spd=F / 60.)

        if X is not None:
            x_delta = X
            if not self.relative:
                x_delta -= self.x
        else:
            x_delta = 0

        if Y is not None:
            y_delta = Y
            if not self.relative:
                y_delta -= self.y
        else:
            y_delta = 0

        las_setting = "default" if self.las_on else "blank"
        retval = self.laser_cut(x_delta, y_delta, las_setting=las_setting)
        if retval > 0:
            raise RuntimeError("G1 Switch was triggered: " + bin(retval))
        elif retval < 0:
            raise RuntimeError("G1 Command failed")


    def G20(self):
        """ G20: Set Units to Inches

        NOT IMPLEMENTED

        :return: void
        """
        raise NotImplementedError("G20 Set Units to Inches not implemented")


    def G21(self):
        """ G21: Set Units to mm

        NOT IMPLEMENTED

        :return: void
        """
        raise NotImplementedError("G21 Set Units to mm not implemented")


    def G28(self):
        """ G28: Move to origin (Home)
        :return: void
        """

        if self.home_xy() != 0:
            raise RuntimeError("G28 Homing sequence failed")


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


    def G92(self, X=0, Y=0):
        """ G92: Set Position

        Sets the current position to the values given without moving.
        If x or y are not specified, they are set to 0.

        :param x: New x position (default 0)
        :type: double
        :param y: New y position (default 0)
        :type: double
        :return: void
        """
        try:
            float(X)
            float(Y)
        except ValueError:
            raise RuntimeError("G92: Position parameter not a number:" + str(X))

        self.x, self.y = X, Y

####################### M Code Functions ################################
    """ M0: Unconditional Stop
        M1: Sleep
        M3: Spindle On (Laser On)
        M5: Spindle Off (Laser Off)
        M17: Enable All Stepper Motors
        M18: Disable All Stepper Motors
        M42: Switch I/O Pin
        M72: Play a Tone or Song
        M92: Set Axis Steps Per Unit
        M106: Fan On
        M107: Fan Off
        M114: Get Current Position
        M115: Get Firmware Version and Capabilities
        M119: Get Endstop Status
    """
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


    def M0(self):
        """ M0: Unconditional Stop

        Turns off all motors and laser, then throws exception to quit everything

        :return: void
        """

        self.las_on = False
        self.mots_en(0)
        # TODO Change stopall exception to something less lethal than SystemExit
        raise SystemExit("M0: Unconditional Stop called")


    def M1(self):
        """ M1: Sleep

        Turns off all motors and laser.

        :return: void
        """

        self.las_on = False
        self.mots_en(0)


    def M3(self, S=None):
        """ M3: Spindle On (Laser On)

        Adapted from standard G-code M3: Spindle On at S(RPM).
        Currently sets laser power to on or off, no in-between.
        Laser only fires while moving with G1.

        :param s: Laser power
        :type: int
        :return: void
        """

        self.las_on = True if S else False


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

        self.mots_en(1)


    def M18(self):
        """ M18: Disable All Stepper Motors

        :return: void
        """

        self.mots_en(0)


    def M42(self, P=None, S=None):
        """ M42: Switch I/O Pin

        NOT IMPLEMENTED

        :param p: Which pin to switch (RPi physical numbering)
        :type: int
        :param s: Pin value
        :type: int
        :return: void
        """

        raise NotImplementedError("M42 Switch I/O Pin not implemented")


    def M72(self, P=None):
        """ M72: Play a Tone or Song

        NOT IMPLEMENTED

        :param p: ID code for which song to play
        :type: int
        :return: void
        """

        raise NotImplementedError("M72 Play a Tone or Song not implemented")


    def M92(self, X=None, Y=None):
        """ M92: Set Axis Steps Per Unit

        Sets step_cal to X or Y, or just X if both are give

        :param x: steps/mm value
        :type: double
        :param y: steps/mm value
        :type: double
        :return: void
        """

        if X is not None:
            self.step_cal = X
        elif Y is not None:
            self.step_cal = Y


    def M106(self, P=None, S=None):
        """ M106: Fan On

        NOT IMPLEMENTED

        :param p: Fan ID number (default 0)
        :type: int
        :param s: Fan speed (0-255)
        :type: int
        :return: void
        """

        raise NotImplementedError("M106 Fan On not implemented")


    def M107(self):
        """ M107: Fan Off

        NOT IMPLEMENTED

        :return: void
        """

        raise NotImplementedError("M107 Fan Off not implemented")


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

        return self.read_sws() & 0xf
