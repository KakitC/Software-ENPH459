"""
debugScript.py
A method of testing code by using a script instead of the
interpreter. Uses debugImport.py to do all the setup.
"""

# Import everything
execfile("dbgImport.py")

gman.set_step_cal(10)

# gman.G28()  # home
# gman.G90()  # absolute
gman.mots_en(0)

try:

    # for i in range(4, 10, 1):
    #     # Move around in a square for motion demo
    #     print "Speed (mm/s): ", i
    #     gman.G0(0, 0, i*60)
    #     gman.G0(10, 0)
    #     gman.G0(10, 10)
    #     gman.G0(0, 10)
    #
    # for i in range(10, 120, 10):
    #     # Move around in a square for motion demo
    #     print "Speed (mm/s): ", i
    #     gman.G0(0, 0, i*60)
    #     gman.G0(100, 0)
    #     gman.G0(100, 100)
    #     gman.G0(0, 100)
    file = "raster_test6"
    dpmm = 10
    travel_feed = 100 * 60
    cut_feed = 2*60

    start = time.clock()
    pic = ipsR.raster_dither("testfiles/" + file + ".jpg", dpmm)
    """:type: PIL.Image.Image"""
    pic.save("output/" + file + ".jpg")
    ips_time = time.clock()
    print "IPS time: {}".format(ips_time - start)

    gman.set_las_mask(pic, dpmm)

    ipsR.gen_gcode("output/" + file + ".gcode", pic, dpmm, travel_feed,
                   cut_feed)
    gcode_time = time.clock()
    print "Gcode gen time: {}".format(gcode_time - ips_time)

    gman.parse_gcode("output/" + file + ".gcode")
    parse_time = time.clock()
    print "Parse time: {}".format(parse_time - gcode_time)

except Exception:
    gman.M1()
    raise
