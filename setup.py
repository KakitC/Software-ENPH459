"""
setup.py
Build file for Cython extensions
"""

from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

extensions = [
    Extension("hardwareDriver",
              ["hardwareDriver.pyx"],
              libraries=["bcm2835"]
              )
    ,
    # Extension("hardwareDriverPigpio",
    #           ["hardwareDriverPigpio.pyx"],
    #           libraries=["pigpio", "rt"]
    #           )
    # ,
    Extension("HManHelper",
              ["HManHelper.pyx"]
              )
]
setup(
    ext_modules=cythonize(extensions)
)