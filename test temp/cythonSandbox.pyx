# from cpython cimport array
# import array
#
# cdef array.array a = array.array('i', [i for i in range(5)])
# cdef array.array b = array.array('i', [i for i in range(5)])
# for i in range(5):
#     print a.data.as_ints[i]
#     print b.data.as_ints[i]

class TestClass:
    b = 2

    def __init__(self):
        self.x = 3
        cdef int y = 4
        a = 1
        print a
        print self.b
        print self.x
        print y


    def gen_step_list(x_start, y_start, x_end, y_end, step_cal=12.7):
        """ Create a list of A/B steps from X/Y coordinates and step size.

        Uses Bresenhem line rasterization algorithm.

        :param x_start: x start position, in mm
        :type: double
        :param y_start:
        :type: double
        :param x_end:
        :type: double
        :param y_end:
        :type: double
        :param step_cal: steps/mm. 12.7 steps/mm by calculations
        :type: double
        :return: n by 2 list of A/B steps (+/- 1 or 0)
        """

        cdef double x_delta = x_end - x_start
        cdef double y_delta = y_end - y_start

        # Convert to A,B pixels delta
        cdef int a_delta = int(round((x_delta + y_delta) * step_cal))
        cdef int b_delta = int(round((x_delta - y_delta) * step_cal))

        # Divide into quadrants by reversing directions as needed
        cdef bint a_flip_flag = False
        cdef bint b_flip_flag = False
        cdef bint ab_flip_flag = False

        if a_delta < 0:
            a_delta = -a_delta
            a_flip_flag = True
        if b_delta < 0:
            b_delta = -b_delta
            b_flip_flag = True

        # Divide into octants by swapping so A > B
        if b_delta > a_delta:
            a_delta, b_delta = b_delta, a_delta # yep, that's safe /s
            ab_flip_flag = True

        # Generate step list for line in first octant. Bresenham's algo here
        # TODO Optimize step_list gen by using C arrays?
        step_list = []
        cdef int a_now = 0
        cdef int error = 2*b_delta - a_delta
        while a_now < a_delta:
            a_now += 1
            ab_list = [1,0]
            error += 2*b_delta
            if error >= 0:
                ab_list[1] = 1
                error -= 2*a_delta
            step_list.append(ab_list)

        # Reverse octants, quadrants
        if ab_flip_flag:
            step_list = [[_[1], _[0]] for _ in step_list]

        if a_flip_flag:
            step_list = [[-_[0], _[1]] for _ in step_list]
        if b_flip_flag:
            step_list = [[_[0], -_[1]] for _ in step_list]

        return step_list