"""
scanBlock.py
For getting image input from the camera of the laser cutter bed.

Handles image capture and
"""

import picamera as picam
from PIL import Image
import time
import io


def scan_bed(gman, area):
    """ Take a series of images of the workpiece and return a whole image.

    Performs a scanning routine, taking multiple images and stitches together
    a whole picture. Does not handle limiting the size of the image to the bed.

    :param gman: Gcode interface to laser cutter hardware
    :type: GcodeInterface
    :param area: The size of the scan in mm, either a linear dimension
    (squared), (length, width) of the area to scan, or a 4-tuple of (xmin,
    ymin, xmax, ymax)
    :type: double, 2-tuple <double>, or 4-tuple <double>
    :return: Picture of the workpiece
    :rtype: PIL.Image.Image
    """

    # Calibration parameters
    # TODO move calibration params to dictionary from CTL layer
    cam_fov = (12, 16)  # Undistorted camera FoV area on focus plane in mm
    cam_feed = 100 * 60  # image taking feedrate (mm/min)
    resolution = (160, 120)  # Camera image resolution
    cam_rot = 90
    delay = .1  # Seconds to wait before taking picture
    overlap = (.5, .5)  # Fraction overlap on x, y between pictures.
    # Depends on cam_fov setting.
    offset = (30, 0)  # Camera center offset from (0,0)
    # shutter_speed =
    # iso =
    # awb_mode = "off"
    # TODO report pixel/mm scaling value?


    try:
        xmin, ymin = 0, 0
        xmax = float(area)
        ymax = xmax
    except ValueError: # area was not a single number
        if len(area) == 4:  # 4tuple bounding box
            xmin, ymin, xmax, ymax = area
        elif len(area) == 2:  # 2tuple size
            xmin, ymin = 0, 0
            xmax, ymax = area
        else:  # lol what is this
            raise ValueError("Invalid area parameter")

    pics_arr = []
    # with picam.PiCamera() as cam:
    try:
        cam = picam.PiCamera()
        # Init
        cam.resolution = resolution
        # cam.start_preview(alpha=128)  # debug

        if not gman.homed:
            gman.G28()

        gman.G90()
        # TODO Account for laser being offset from cutting spot
        for j in range(int((ymax - ymin) / cam_fov[1]) + 1):
            pics_arr.append([])
            for i in range(int((xmax - xmin) / cam_fov[0]) + 1):
                stream = io.BytesIO()
                gman.G0((i + .5) * cam_fov[0], (j + .5) * cam_fov[1], cam_feed)
                time.sleep(delay)  # wait for motion to stop, camera adjust
                cam.capture(stream, format='jpeg')
                stream.seek(0)
                pic_ji = Image.open(stream).convert(mode='L')
                pics_arr[j].append(pic_ji.transpose(Image.ROTATE_90))
                # TODO Remove rotate 90 deg when camera is changed
        cam.close()
        pic = _scan_stitch(pics_arr, resolution, overlap)
        # TODO Crop pic to given area and pad
        return pic
    except Exception:
        print "Exception happened"
        cam.close()
        raise



def _scan_stitch(pics_arr, resolution, overlap):
    """ Combine an array of Images together into one PIL Image

    Relies on knowing the location of each image being taken, doesn't actually
    do proper image stitching feature recognition

    :param pics_arr:
    :return: Single picture of scanning bed area
    """
    # TODO Apply geometric lens anti transform
    # (not real image stitching, naive)
    pic = Image.new("L", (len(pics_arr[0]) * resolution[1] * (1 - overlap),
                          len(pics_arr) * resolution[0]) * (1 - overlap),
                    color="white")
    for j, col in enumerate(pics_arr):
        for i, row in enumerate(col):
            # pic.paste(pics_arr[j][i], (i*resolution[1] * (1 - overlap),
            #                            j*resolution[0]) * (1 - overlap))
            # Put new image to correct position
            # coordinates for new image
            top = i * resolution[1] * (1 - overlap[1])
            left = j * resolution[0] * (1 - overlap[0])
            pad = Image.new("L", pic.size)
            pad.paste(pics_arr[j][i], (top, left))

            # Set blend mask: 0 for keep, 127 for overlap, 255 for new
            mask = Image.new("L", pic.size)  # init to 0
            # grey box size of img
            mask.paste(127, (left, top, left + pics_arr[j][i].size[0],
                             top + pics_arr[j][i].size[1]))
            # White box, extends all the way down/right
            left_offset = left if j == 0 else left + resolution[0] * overlap[0]
            top_offset = top if i == 0 else top + resolution[1] * overlap[1]
            mask.paste(255, (left_offset, top_offset))

            pic = Image.composite(pic, pad, mask)

    return pic
