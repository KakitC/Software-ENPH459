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
    cam_fov_x, cam_fov_y = 32, 24  # Undistorted camera FoV in mm
    cam_feed = 100 * 60  # image taking feedrate (mm/min)
    resolution = (640, 480)
    # shutter_speed =
    # iso =
    # awb_mode = "off"


    try:
        xmin, ymin = 0, 0
        xmax = float(area)
        ymax = xmax
    except ValueError:
        if len(area) == 4:
            xmin, ymin, xmax, ymax = area
        elif len(area) == 2:
            xmin, ymin = 0, 0
            xmax, ymax = area
        else:
            raise ValueError("Invalid area parameter")

    pics_arr = []
    # with picam.PiCamera() as cam:
    try:
        cam = picam.PiCamera()
        # Init
        cam.resolution = resolution
        # cam.start_preview(alpha=128)  # debug
        stream = io.BytesIO()

        if not gman.homed:
            gman.G28()

        gman.G90()
        for j in range((ymax - ymin) / cam_fov_y + 1):
            pics_arr.append([])
            for i in range((xmax - xmin) / cam_fov_x + 1):
                gman.G0((i + .5) * cam_fov_x, (j + .5) * cam_fov_y, cam_feed)
                time.sleep(.2)  # wait for motion to stop, camera adjust
                cam.capture(stream, format='jpeg')
                stream.seek(0)
                pics_arr[j].append(Image.open(stream).convert(mode='L'))

        cam.close()
        pic = _scan_stitch(pics_arr, cam_fov_x, cam_fov_y)
        return pic
    except Exception:
        print "Exception happened"
        cam.close()
        raise



def _scan_stitch(pics_arr, cam_fov_x, cam_fov_y):
    """ Combine an array of Images together into one PIL Image
    :param pics_arr:
    :return: Single picture of scanning bed area
    """

    # TODO Apply geometric lens anti transform
    # TODO use alpha blend mask
    pic = Image.new("L", (len(pics_arr[0])*cam_fov_x, len(pics_arr)*cam_fov_y),
                    color="white")
    for j, col in enumerate(pics_arr):
        for i, row in enumerate(col):
            pic.paste(pics_arr[j][i], (i*cam_fov_x, j*cam_fov_y))
    return pic
