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

cdef int[:] list = array.array('i', range(5))
print len(list)
cdef int TEST[5]
#cdef int BUTTS[len(list)]
for i in list:
    TEST[i] = i*3
#    BUTTS[i] = i*2

cdef testfun():
    i = 5
    i += 1
    print i
