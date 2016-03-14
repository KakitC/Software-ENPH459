"""
cythonSandbox.pyx
Test Cython file for checking Cython syntax in Windows without needing to
build Linux libraries
"""
from cpython cimport array
# import array
#
# cdef array.array a = array.array('i', [i for i in range(5)])
# cdef array.array b = array.array('i', [i for i in range(5)])
# for i in range(5):
#     print a.data.as_ints[i]
#     print b.data.as_ints[i]

cdef testfun():
    i = 5
    i += 1
    print i

cdef int a = 5
cdef int b = 5

cdef enum:
    x, y, z

cdef enum:
    d = 5
    e = 6
    f = 7

print d
