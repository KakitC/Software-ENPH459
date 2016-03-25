"""
debugScript.py
A method of testing code by using a script instead of the
interpreter. Uses debugImport.py to do all the setup.
"""

# Import everything
# TODO change to only if everything not imported
execfile("dbgImport.py")

gman.set_step_cal(10)

# gman.G28()  # home
# gman.G90()  # absolute
gman.mots_en(0)

try:

    file = "raster_cal4.png"
    scaling = 10
    travel_feed = 100 * 60
    cut_feed = 2*60

    start = time.clock()
    # pic = ipsR.raster_dither("testfiles/" + file, scaling, pad=(10, 10))
    # """:type: PIL.Image.Image"""
    # pic.save("output/" + file)
    # ips_time = time.clock()
    # print "IPS time: {}".format(ips_time - start)
    #
    # gman.set_las_mask(pic, scaling)
    #
    # ipsR.gen_gcode("output/" + file[0:-4] + ".gcode", pic, scaling, travel_feed,
    #                cut_feed)
    # gcode_time = time.clock()
    # print "Gcode gen time: {}".format(gcode_time - ips_time)
    #
    # gman.parse_gcode("output/" + file[0:-4] + ".gcode")
    # parse_time = time.clock()
    # print "Parse time: {}".format(parse_time - gcode_time)
    pic = scn.scan_bed(gman, 100)
    pic.save("output/bed_scan.png")


except Exception:
    gman.M1()  # STOP
    gman.M0()  # STAAAHP
    raise      # GET OUT
