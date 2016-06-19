"""
cythonSandbox.pyx
Test Cython file for checking Cython syntax in Windows without needing to
build Linux libraries
"""
from cpython cimport array
# import array
from math import *
import pigpio as pig
from cymem.cymem cimport Pool

# Define external functions
cdef extern from "sys/time.h":
    struct timeval:
        int tv_sec
        int tv_usec
    int gettimeofday(timeval *timer, void *)

# Import pigpio c lib functions and vars
cdef extern from "pigpio.h":
    ctypedef int uint8_t
    ctypedef int uint32_t
    ctypedef int unsigned

    ctypedef struct gpioPulse_t:
        uint32_t gpioOn
        uint32_t gpioOff
        uint32_t usDelay

    # GPIO init functions
    int gpioInitialise()
    int gpioTerminate()

    # GPIO functions
    int gpioSetMode(unsigned gpio, unsigned mode) # Set pin I or O
    int gpioGetMode(unsigned gpio)  # Reads GPIO mode
    int gpioRead(unsigned gpio)  # Read pin
    int gpioWrite(unsigned gpio, unsigned level)  # Sets pin
    int gpioSetPullUpDown(unsigned gpio, unsigned pud)  # Sets pull up/down
    # vs bcm2835: missing set/clr functions, set/clr/write multi, interrupts

    # GPIO Wave functions
    int gpioWaveClear()
    int gpioWaveAddNew()
    int gpioWaveAddGeneric(unsigned numPulses, gpioPulse_t *pulses)
    int gpioWaveCreate()
    int gpioWaveGetPulses()
    int gpioWaveGetCbs()
    int gpioWaveGetMicros()

    # Not included: SPI functions, I2C, serial
    # pigpio uses BCM pin numbering, not physical

    # Delays who knows how long lol
    uint32_t gpioDelay(uint32_t micros)  # delay micros

    # # Port function select modes for bcm2835_gpio_fsel()
    # int GPIO_INPUT "PI_INPUT "# = 0b000,   ///< Input
    # int GPIO_OUTPUT "PI_OUTPUT" # = 0b001,   ///< Output
    # # Other definitions
    # int HI "PI_HIGH"
    # int LO "PI_LOW"
    #
    # int PUD_OFF "PI_PUD_OFF"
    # int PUD_DOWN "PI_PUD_DOWN"
    # int PUD_UP "PI_PUD_UP"

# Define vars
cdef int USEC_PER_SEC = 1000000
cdef int GPIO_INPUT = 0
cdef int GPIO_OUTPUT = 1

cdef int PUD_OFF = 0
cdef int PUD_DOW = 1
cdef int PUD_UP = 2

############# PIN DEFINITIONS #############

# Motor outputs
# MOT_N is an array, with indices enums EN, STEP, DIR
cdef int EN     = 0  # ACTIVE LOW
cdef int STEP   = 1  # ACTIVE HIGH
cdef int DIR    = 2  # ACTIVE HIGH
cdef int[:] list_of_mot_pins = array.array('i', [EN, STEP, DIR])

cdef int[:] MOT_A = array.array('i', range(3))
MOT_A[EN]       = 2  # _RPI_V2_GPIO_P1_03
MOT_A[STEP]     = 3  # _RPI_V2_GPIO_P1_05
MOT_A[DIR]      = 4  # _RPI_V2_GPIO_P1_07
# GND           = GPIO_09

cdef int[:] MOT_B = array.array('i', range(3))
MOT_B[EN]       = 14  # _RPI_V2_GPIO_P1_08
MOT_B[STEP]     = 15  # _RPI_V2_GPIO_P1_10
MOT_B[DIR]      = 18  # _RPI_V2_GPIO_P1_12
# GND           = GPIO_14

# Laser output
LAS             = 7  # _RPI_V2_GPIO_P1_26  # ACTIVE HIGH

# All input switches
cdef int XMIN       = 0
cdef int XMAX       = 1
cdef int YMIN       = 2
cdef int YMAX       = 3
cdef int SAFE_FEET  = 4
cdef int[:] list_of_sw_pins = array.array('i', (XMIN, XMAX, YMIN, YMAX,
                                                SAFE_FEET))
# Active low
cdef int[:] SWS = array.array('i', range(5))
SWS[XMIN]   = 27  # _RPI_V2_GPIO_P1_13
SWS[XMAX]   = 22  # _RPI_V2_GPIO_P1_15
# Vcc (3V3) = GPIO_17
SWS[YMIN]   = 9  # _RPI_V2_GPIO_P1_21
SWS[YMAX]   = 10  # _RPI_V2_GPIO_P1_19  # woops wires
SWS[SAFE_FEET] = 11  # _RPI_V2_GPIO_P1_23  # woops active hi by accident
# GND       = GPIO_25

# 0, 1, 5, 6, 12, 13, 16, 19, 26, 20, 21 unused for sure

def testScript():
    if not gpioInitialise():
        raise IOError

    gpioSetMode(0, GPIO_OUTPUT)
    gpioSetMode(1, GPIO_OUTPUT)

    cdef gpioPulse_t *pulse1
    mem = Pool()
    pulse1 = <gpioPulse_t*> mem.alloc(1, sizeof(gpioPulse_t))
    pulse1.usDelay = 500000
    pulse1.gpioOn = 1 << 1
    pulse1.gpioOff = 1 << 0

    cdef gpioPulse_t *pulse2 = pulse1
    # cdef int[:] pulse1 = array.array('i', [1 << 1, 1 << 0, 500000])
    # cdef int[:] pulse2 = array.array('i', [1 << 0, 1 << 1, 500000])
    #
    # cdef int[:,:] pulses = array.array('i', [[1 << 1, 1 << 0, 500000],
    #                                         [1 << 0, 1 << 1, 500000]])

    print "pulse1.usDelay", pulse1.usDelay
    print "pulse2.usDelay", pulse2.usDelay

    gpioWaveAddGeneric(2, [pulse1[0], pulse2[0]])
    # waveid = gpioWaveCreate()
    # print waveid
    print "gpioWaveGetMicros", gpioWaveGetMicros()

    pulse1.usDelay = 250000
    print "pulse1.usDelay", pulse1.usDelay
    print "pulse2.usDelay", pulse2.usDelay
    print "gpioWaveGetMicros", gpioWaveGetMicros()

    print EN
    print MOT_A[EN]

    gpioTerminate()