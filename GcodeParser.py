"""
GcodeParser.py
Parses valid G-code files, then calls the GcodeInterface functions to
execute G-code commands.
"""
__author__='kakit'

def parse_gcode(filename, gman):
    """ Read gcode from a filepath, and execute the commands.

    Raises IOError if file cannot be opened.

    Raises a SyntaxWarning if there as an issue with the G-code parsing, due
    either to the file being formatted incorrectly or the parser behaving
    unexpectedly.

    Passes along the StandardError exception of some kind if there is an issue
    with executing the commands.

    :param filepath: Directory path of the G-code file, absolute or relative
    :type: string
    :param filename: Name of the G-code text file.
    :type: string
    :return: void, exceptions for errors.
    """

    try:
       infile = open(filename)  # mode 'r'
    except:
        raise

    lines = infile.readlines()

    clist = gman.cmd_list