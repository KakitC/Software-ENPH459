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
skew = 0 #.2
step_cal = 10

set_dic = {
    'scaling' : scaling,
    "travel_feed" : travel_feed,
    "cut_feed" : cut_feed,
    "bed_xmax" : bed_xmax,
    "bed_ymax" : bed_ymax,
    "skew" : skew,
    "step_cal" : step_cal
}

gman.set_step_cal(step_cal)
gman.set_spd(cut_spd=cut_feed / 60, travel_spd=travel_feed / 60)
gman.set_bed_limits(bed_xmax, bed_ymax)
gman.set_skew(skew)
# TODO Debug this
# gman.set_settings(set_dic)

try:

#     name = "raster_cal0.png"
#     blackwhite = False
#     pad = (180, 0)
#
#     start = time.clock()
#     pic = ipsR.raster_dither("testfiles/" + name, scaling, pad=pad,
#                              blackwhite=blackwhite)
#     """:type: PIL.Image.Image"""
#     pic.save("output/" + name)
#     ips_time = time.clock()
#     print "IPS time: {}".format(ips_time - start)
#
#     gman.set_las_mask(pic, scaling)
#
#     ipsR.gen_gcode("output/" + name[0:-4] + ".gcode", pic, set_dic)
# #                   scaling, travel_feed, cut_feed)
#     gcode_time = time.clock()
#     print "Gcode gen time: {}".format(gcode_time - ips_time)
#
#     gman.parse_gcode("output/" + name[0:-4] + ".gcode")
#     parse_time = time.clock()
#     print "Parse/execute time: {}".format(parse_time - gcode_time)

    gman.set_las_mask([[0]], 0.0000000001)
    gman.G28()
    gman.G90()
    gman.M3(S=255)

    # Cut big square
    gman.G1(X=200, Y=0, F=cut_feed)
    gman.G1(X=200, Y=200, F=cut_feed)
    gman.G1(X=0, Y=200, F=cut_feed)
    gman.G1(X=0, Y=0, F=cut_feed)
    gman.G1(X=200, Y=200, F=cut_feed)  #diagonal
    gman.G0(X=0, Y=200, F=travel_feed)  #diagonal
    gman.G1(X=200, Y=0, F=cut_feed)

    gman.M5()
    gman.G28()

    # print "Scanning bed"
    # pic = scn.scan_bed(gman, 50)
    # pic.save("output/bed_scan.png")


except Exception:
    gman.M1()  # STOP
    # gman.M0()  # STAAAHP
    raise      # GET OUT
