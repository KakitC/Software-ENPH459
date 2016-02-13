# from cpython cimport array
# import array
#
# cdef array.array a = array.array('i', [i for i in range(5)])
# cdef array.array b = array.array('i', [i for i in range(5)])
# for i in range(5):
#     print a.data.as_ints[i]
#     print b.data.as_ints[i]

class TestClass:

    def test_foo(self, int i, double f):
        print i
        print f