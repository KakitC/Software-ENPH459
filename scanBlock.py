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
        # TODO fix: or TypeError
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
    except Exception:  # TODO check this catches any errors on closing
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
    # size = int(resolution * (n - (n-1) overlap))
    pic = Image.new("L", (int(resolution[0] *
                             ((len(pics_arr[0]) - 1) * (1 - overlap[0]) + 1)),
                          int(resolution[1] *
                             ((len(pics_arr[1]) - 1) * (1 - overlap[1]) + 1))
                          ),
                    color="white")

    # Blend by column, then add to whole picture
    for j, col in enumerate(pics_arr):
        col_pic = Image.new("L", (resolution[0], pic.size[1]))
        for i, row in enumerate(col):
            sample = col[i]

            top = int(i * resolution[1] * (1 - overlap[1]))
            pad = Image.new("L", col_pic.size)
            pad.paste(sample, (0, top))

            mask = Image.new("L", col_pic.size, 0)
            mask.paste(255, (0, top, sample.size[0], top + sample.size[1]))
            if i > 0:
                mask.paste(127, (0, top, sample.size[0],
                           int(top + sample.size[1] * overlap[1])))

            col_pic.paste(pad, mask=mask)

        left = int(j * resolution[0] * (1 - overlap[0]))
        pad = Image.new("L", pic.size)
        pad.paste(col_pic, (left, 0))

        mask = Image.new("L", pic.size, 0)
        mask.paste(255, (left, 0, left + col_pic.size[0], col_pic.size[1]))
        if j > 0:
            mask.paste(127, (left, 0, int(left + col_pic.size[0] * overlap[0]),
                             col_pic.size[1]))

        # pic = Image.composite(pic, )
        pic.paste(pad, mask=mask)

    return pic

#    # Doesn't work, doesn't account for corners
    # for j, col in enumerate(pics_arr):
    #     for i, row in enumerate(col):
    #         # pic.paste(pics_arr[j][i], (i*resolution[1] * (1 - overlap),
    #         #                            j*resolution[0]) * (1 - overlap))
    #         # Put new image to correct position
    #         # coordinates for new image
    #         sample = pics_arr[j][i]
    #
    #         top = int(i * resolution[0] * (1 - overlap[0]))
    #         left = int(j * resolution[1] * (1 - overlap[1]))
    #         pad = Image.new("L", pic.size)
    #         pad.paste(sample, (left, top))
    #
    #         # Set blend mask: 255 for keep, 127 for overlap, 0 for new
    #         mask = Image.new("L", pic.size, 255)
    #         # grey box size of img
    #         mask.paste(127, (left, top, left + sample.size[0],
    #                          top + sample.size[1]))
    #
    #         # Hard mask box, extends all the way down/right
    #         left_offset = left if j == 0 \
    #             else left + int(resolution[0] * overlap[0])
    #         top_offset = top if i == 0 \
    #             else top + int(resolution[1] * overlap[1])
    #         mask.paste(0, (left_offset, top_offset,
    #                        int(left_offset + sample.size[0] * (1 - overlap[0])),
    #                        int(top_offset + sample.size[1] * (1 - overlap[1]))
    #                        )
    #                    )
    #
    #         pic = Image.composite(pic, pad, mask)
    # return pic

