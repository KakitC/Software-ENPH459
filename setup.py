"""
setup.py
Build file for Cython extensions
"""
__author__ = 'kakit'

from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

extensions = [
    Extension("hardwareDriver",
              ["hardwareDriver.pyx"],
              libraries=["bcm2835"]
              )
    ,
    Extension("HManHelper",
              ["HManHelper.pyx"]
              )
]
setup(
    ext_modules=cythonize(extensions)
)