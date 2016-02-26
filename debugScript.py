"""
debugScript.py
A method of testing code by using a script instead of the
interpreter. Uses debugImport.py to do all the setup.
"""
__author__="kakit"

# Import everything
execfile("debugImport.py")

gman.set_step_cal(12.7)

gman.set_spd(10, 100)

gman.G28()  # home
gman.G90()  # absolute

try:
    while True:
        # Move around in an indented square for motion demo
        gman.G0(0,0)
        gman.G0(100,0)
        gman.G0(100,100)
        gman.G0(0,100)
        gman.G0(40,75)
        gman.G0(50,50)
        gman.G0(75,40)
except Exception:
    gman.mots_en(0)
    raise