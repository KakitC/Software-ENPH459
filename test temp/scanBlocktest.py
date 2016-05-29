from PIL import Image



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
    # pic = Image.new("L", (int(resolution[0] *
    #                          (len(pics_arr[0]) - 1) * (1 - overlap[0])),
    #                       int(resolution[1] *
    #                          (len(pics_arr[1]) - 1) * (1 - overlap[1]))
    #                       ),
    #                 color="white")
    pic = Image.new("L", (resolution[0] * len(pics_arr),
                          resolution[1] * len(pics_arr[0])))

    # Blend by row, then add to whole picture
    for j, row in enumerate(pics_arr):
        row_pic = Image.new("L", (pic.size[0], resolution[1]))
        for i, col in enumerate(row):
            sample = row[i]

            left = int(i * resolution[0] * (1 - overlap[0]))

            pad = Image.new("L", row_pic.size)
            pad.paste(sample, (left, 0))

            mask = Image.new("L", row_pic.size, 0)
            mask.paste(255, (left, 0, left + sample.size[0], sample.size[1]))
            if i > 0:
                mask.paste(127, (left, 0, int(left + sample.size[0] * overlap[0]),
                            sample.size[1]))

            row_pic.paste(pad, mask=mask)

        top = int(j * resolution[1] * (1 - overlap[1]))
        pad = Image.new("L", pic.size)
        pad.paste(row_pic, (0, top))

        mask = Image.new("L", pic.size, 0)
        mask.paste(255, (0, top, row_pic.size[0], top + row_pic.size[1]))
        if j > 0:
            mask.paste(127, (0, top, row_pic.size[0],
                             int(top + row_pic.size[1] * overlap[0])))

        # pic = Image.composite(pic, )
        pic.paste(pad, mask=mask)

    return pic

pics_arr = [[Image.open("output\\" + str(j*5 +i) + ".png") for i in range(5)]
            for j in range(4)]
resolution = (120,160)
overlap = (.1,.1)

out = _scan_stitch(pics_arr, resolution, overlap)
out.show()