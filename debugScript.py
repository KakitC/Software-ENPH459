"""
debugScript.py
A method of testing code by using a script instead of the
interpreter. Uses debugImport.py to do all the setup.
"""

# Import everything
# TODO change to only if everything not imported
execfile("dbgImport.py")
gman.mots_en(0)

# Hardware cal settings
scaling = 10
travel_feed = 100 * 60
cut_feed = 5*60
bed_xmax = 250
bed_ymax = 280
skew = .2

set_dic = {
    'scaling' : scaling,
    "travel_feed" : travel_feed,
    "cut_feed" : cut_feed,
    "bed_xmax" : bed_xmax,
    "bed_ymax" : bed_ymax,
    "skew" : skew
}

gman.set_step_cal(scaling)
gman.set_spd(cut_spd=cut_feed / 60, travel_spd=travel_feed / 60)
gman.set_bed_limits(bed_xmax, bed_ymax)
gman.set_skew(skew)
# TODO Debug this
#gman.set_settings(set_dic)

try:

    file = "raster_cal0.png"

    start = time.clock()
    pic = ipsR.raster_dither("testfiles/" + file, scaling, pad=(10, 10),
                             blackwhite=True)
    """:type: PIL.Image.Image"""
    pic.save("output/" + file)
    ips_time = time.clock()
    print "IPS time: {}".format(ips_time - start)

    gman.set_las_mask(pic, scaling)

    ipsR.gen_gcode("output/" + file[0:-4] + ".gcode", pic, set_dic)
#                   scaling, travel_feed, cut_feed)
    gcode_time = time.clock()
    print "Gcode gen time: {}".format(gcode_time - ips_time)

    gman.parse_gcode("output/" + file[0:-4] + ".gcode")
    parse_time = time.clock()
    print "Parse/execute time: {}".format(parse_time - gcode_time)


    # print "Scanning bed"
    # pic = scn.scan_bed(gman, 50)
    # pic.save("output/bed_scan.png")


except Exception:
    gman.M1()  # STOP
    # gman.M0()  # STAAAHP
    raise      # GET OUT
