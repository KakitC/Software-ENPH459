"""
GcodeParser.py
Parses valid G-code files, then calls the GcodeInterface functions to
execute G-code commands.
"""
__author__='kakit'

from GcodeInterface import GcodeInterface
import re


def parse_gcode(filename, gman):
    """ Read gcode from a filepath, and execute the commands.

    Raises IOError if file cannot be opened.

    Raises a SyntaxWarning if there as an issue with the G-code parsing, due
    either to the file being formatted incorrectly or the parser behaving
    unexpectedly.

    Passes along the StandardError sub-exception of some kind if there is an
    issue with executing the commands.

    :param filename: Directory path of the G-code file, absolute or relative
    :type: string
    :param gman: GcodeInterface for executing commands on hardware
    :type: GcodeInterface
    :return: void, exceptions for errors.
    """

    try:
       infile = open(filename)  # mode 'r'
    except:
        print("Could not open file")
        raise

    lines = infile.readlines()
    execlist =[]

    # Gcode parsing rules:
    # Ex: N3 G1 X10.3 Y23.4 *34 ; comment
    #
    # Strip comments
    # Strip any line number (N) fields
    # Strip checksums
    # Parse actual command
    for i, j in lines, range(len(lines)):
        orig_line = i
        i = i.upper()
        i = i[0:i.find(";")]  # strip comments
        i = i.strip()
        i = re.sub(r"N[0-9]*\s", "", i, 1)  # strip line numbers
        i = i[0:i.find("*")]  # strip checksum

        # Parse command into python code
        line = i.split()
        execstr = "gman."
        for cmd in gman.cmd_list:
            cmd = cmd.split()

            if line[0] == cmd[0]:  # found it
                execstr += cmd[0] + "("  # construct direct python function call
                cmd.pop(0)
                line.pop(0)

                # TODO Parse Gcode parameters (X Y F S P)

                execstr += ")"
                execlist.append(execstr)
                break  # done making command for this line
        else: # call not found in cmd_list
            raise SyntaxError("G-code file parsing error: Command not found"
                              "at \n" + "line " + str(j) + ": " + orig_line)
    # Finished parsing file
    infile.close()

    # TODO should this be changed to execute line by line? Currently parses all
    for execstr in execlist:
        exec(execstr)
