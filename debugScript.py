"""
debugScript.py
A method of testing code by using a script instead of the
interpreter. Uses debugImport.py to do all the setup.
"""
__author__="kakit"

# Import everything
execfile("dbgImport.py")

gman.set_step_cal(10)

gman.G28()  # home
gman.G90()  # absolute

try:

    for i in range(4, 10, 1):
        # Move around in a square for motion demo
        print "Speed (mm/s): ", i
        gman.G0(0, 0, i*60)
        gman.G0(10, 0)
        gman.G0(10, 10)
        gman.G0(0, 10)

    for i in range(10, 120, 10):
        # Move around in a square for motion demo
        print "Speed (mm/s): ", i
        gman.G0(0, 0, i*60)
        gman.G0(100, 0)
        gman.G0(100, 100)
        gman.G0(0, 100)

except Exception:
    gman.mots_en(0)
    raise
