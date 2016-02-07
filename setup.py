__author__ = 'kakit'

from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

setup(
    ext_modules=cythonize([Extension("hardwareDriver", ["hardwareDriver.pyx"],
              libraries=["bcm2835"])])
)
# setup(
#     ext_modules=cythonize([Extension("arrayTest", ["arrayTest.pyx"])])
# )