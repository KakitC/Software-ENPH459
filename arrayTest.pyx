# from cpython cimport array
# import array
#
# cdef array.array a = array.array('i', [i for i in range(5)])
# cdef array.array b = array.array('i', [i for i in range(5)])
# for i in range(5):
#     print a.data.as_ints[i]
#     print b.data.as_ints[i]

cdef enum MOT_PINS:
    EN       = 0
    STEP     = 1
    DIR      = 2

MOT_A = range(3)
MOT_A[EN]       = 1
MOT_A[STEP]     = 1
MOT_A[DIR]      = 1