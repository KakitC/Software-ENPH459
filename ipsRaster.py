"""
ipsRaster.py
Image processing functions for the raster image engraving control path.

pic: actual picture
px: pixel position
pix: pixel value
"""

__author__ = 'kakit'

from PIL import Image, ImageFilter, ImageStat, ImageEnhance, ImageChops, \
    ImageOps


def raster_ips(in_file):
    """ Convert an image to greyscale, and tweak the contrast/brightness and
    low-pass filter until it is ready to be sent to the laser as a power/speed
    bitmap.
    :param in_file: <string> relative file path and name of input image
    :return: Image converted to raster bitmap
    """

    # Main processing blocks, filters
    with Image.open(in_file) as pic:
        pic = pic.convert(mode="L")  # To greyscale

        edges = pic.filter(ImageFilter.CONTOUR)  # Pick out edges
        edges = edges.filter(ImageFilter.SMOOTH_MORE)  # Smooth noise

        pic = pic.filter(ImageFilter.SMOOTH_MORE)  # Smooth noise in original

        # Brightness leveling for dark images
        brightness = ImageStat.Stat(pic).mean
        if brightness[0] < 100:
            pic = ImageEnhance.Brightness(pic).enhance(1.75)
        elif brightness[0] < 120:
            pic = ImageEnhance.Brightness(pic).enhance(1.2)

        pic = ImageChops.multiply(pic, edges)  # Recombine edges for crispness
        pic = pic.convert("1")  # Uses Floyd-Steinberg dithering by default

        # pic = ImageOps.posterize(pic, 1)  # Down from grey to black and white
        # pic = ImageOps.autocontrast(pic)  # Convert grey to white, black same

        return pic
