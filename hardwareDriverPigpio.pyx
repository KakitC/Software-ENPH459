"""
hardwareDriverPigpio.pyx
A Cython module for all low-level hardware access functions, containing all
GPIO functions. Uses the pigpio library for DMA based stepper timings.
Intended to be a drop-in replacement for the original hardwareDriver module.
"""
__author__ = 'Kakit'

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

    # Multi pin functions; Should only be needing pins 0-31
    int gpioRead_Bits_0_31()
    int gpioRead_Bits_32_53()
    int gpioWrite_Bits_0_31_Clear(uint32_t bits)
    int gpioWrite_Bits_32_53_Clear(uint32_t bits)
    int gpioWrite_Bits_0_31_Set(uint32_t bits)
    int gpioWrite_Bits_32_53_Set(uint32_t bits)

    # vs bcm2835: missing interrupts

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
cdef int HI = 1
cdef int LO = 0

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

# Pin number masks
cdef int motor_pin_mask = 0
for pin in list_of_mot_pins:
    assert MOT_A[pin] < 32  # All pins should be 0-31 for multi pin set/clear
    assert MOT_B[pin] < 32
    motor_pin_mask |= 1 << MOT_A[pin]
    motor_pin_mask |= 1 << MOT_B[pin]

cdef int output_pin_mask = motor_pin_mask
assert LAS < 32
output_pin_mask |= 1 << LAS

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

cdef int switch_pin_mask = 0
for pin in list_of_sw_pins:
    switch_pin_mask |= 1 << SWS[pin]
# 0, 1, 5, 6, 12, 13, 16, 19, 26, 20, 21 unused for sure

############### External Interface Functions ##########################

cpdef int gpio_init():
    """ Initialize GPIO pins on Raspberry Pi. Make sure to run program
    in "sudo" to allow GPIO to run.

    :return: 0 if success, else 1
    """

    # Init GPIO
    if not gpioInitialise():
        return 1
    # Set output and input pins
    # Outputs
    for outpin in list_of_mot_pins:
        gpioSetMode(MOT_A[outpin], GPIO_OUTPUT)
        gpioSetMode(MOT_B[outpin], GPIO_OUTPUT)

    gpioSetMode(LAS, GPIO_OUTPUT)

    # Inputs
    for inpin in list_of_sw_pins:
        gpioSetMode(SWS[inpin], GPIO_INPUT)
    
    #print "GPIO Initialization successful"
    return 0


cpdef void gpio_close():
    """ Close GPIO connection. Call this when GPIO access is complete.

    :return: void
    """

    gpioTerminate()


cpdef void gpio_test():
    """ Toggles all mot pins rapidly for 5s. Don't call this while things are
    connected to the pins!

    :return: void
    """

    gpio_init()

    cdef timeval now, then
    gettimeofday(&then, NULL)
    gettimeofday(&now, NULL)
    # TODO switch to multi set/clear function
    while time_diff(then, now) < 5*USEC_PER_SEC:
        gpioWrite_Bits_0_31_Set(output_pin_mask)
        gpioWrite_Bits_0_31_Clear(output_pin_mask)


cpdef void motor_enable():
    """ Set stepper motor Enable pins

    :return: void
    """

    # Active low
    gpioWrite(MOT_A[EN], HI)
    gpioWrite(MOT_B[EN], HI)


cpdef void motor_disable():
    """ Clear stepper motor Enable pins

    :return: void
    """

    # Active low
    gpioWrite(MOT_A[EN], LO)
    gpioWrite(MOT_B[EN], LO)


cpdef void las_pulse(double time):
    """ Turn on the laser output for a given time, then turn off.

    For testing laser functionality. Don't have a function allowing raw access
    to laser GPIO, meaning accidentally leaving it on indefinitely. Disables
    laser if safety feet are triggered.

    :param time: Pulse length in seconds
    :type: int
    :return: void
    """

    gpioWrite(LAS, HI)
    cdef timeval start, end
    gettimeofday(&start, NULL)
    gettimeofday(&end, NULL)
    # TODO Change to DMA wave based pulse
    while time_diff(start, end) < time * USEC_PER_SEC:
        gettimeofday(&end, NULL)
        if read_switches_fast() & (0x1 << SAFE_FEET):
            break
    gpioWrite(LAS, LO)


cpdef int read_switches():
    """ Read values of XY endstop switches and safety feet.

    This is the sensor interface version of the function.

    :return: Bitwise 5-bit value for XMIN, XMAX, YMIN, YMAX, SAFE_FEET (LSB)
            (i.e. 0b01001 => 9: YMAX, XMIN)
    :rtype: int
    """
    cdef int retval = 0
    cdef int mask = 0
    for pin in list_of_sw_pins:
        retval |= (0 if gpioRead(SWS[pin]) else 1 )<< pin

    return retval


cpdef void delay_micros(long us):
    """ Wait for X microseconds somewhat precisely.

    :param us: Time in microseconds to wait
    :return: void
    """

    gpioDelay(us)  # this can return the actual delay time but whatever
    # cdef timeval start, end
    # gettimeofday(&start, NULL)
    # gettimeofday(&end, NULL)
    # while time_diff(start, end) < us:
    #     gettimeofday(&end, NULL)


cpdef void delay_millis(long ms):
    """ Wait for X milliseconds.
    :param ms: Time in millisecodns to wait
    :return: void
    """

    gpioDelay(ms*1000)  # whatever timing in ms range

# TODO Change to pigpio library DMA's for timing/motion
# TODO Check return values on functions to check for errors
cdef int move_laser(step_list, las_list, time_list):
    """ Perform the laser head step motion loop with precise timings.

    :param step_list: List of [a,b] steps to take each increment. 0 or +/-1.
    :type: list[n][2] <integer>
    :param las_list: List of laser on/off value. 0 or 1.
    :type: list[n] <integer>
    :param time_list: List of times (us) to spend at each position
    :type: list[n] <integer>

    :return: Returns associated switch values if endstops or safety feet
    are triggered, else returns 0. See read_switches() for details.
    :rtype: int
    """

    # Convert to C arrays
    cdef int list_len = len(las_list)
    step_listA = zip(*step_list)[0]
    step_listB = zip(*step_list)[1]

    cdef int[:] step_arrA = array.array('i', step_listA)
    cdef int[:] step_arrB = array.array('i', step_listB)
    cdef int[:] las_arr = array.array('i', las_list)
    cdef int[:] time_arr = array.array('i', time_list)

    cdef timeval then, now
    cdef int delta = 0
    cdef int retval = 0

    gettimeofday(&then, NULL)
    gettimeofday(&now, NULL)

    pulseList = []
#    cdef gpioPulse_t[:] pulseArray =

    # # Diagnostics
    # cdef int[:] deltaTimes = array.array('i', range(list_len))
    # cdef int[:] opTimes = array.array('i', range(list_len))

    # cdef int i = 0
    # while i < list_len:
    #     # # Diagnostic
    #     # deltaTimes[i] = delta
    #
    #     # Reset times
    #     then.tv_sec, then.tv_usec = now.tv_sec, now.tv_usec
    #     delta = 0
    #
    #     # Set laser
    #     bcm2835_gpio_write(LAS, las_arr[i])
    #     # bcm2835_gpio_write(LAS, 1 if las_arr[i] else 0)  # 8b power settings
    #
    #     # Move steppers
    #     bcm2835_gpio_write(MOT_A[DIR], step_arrA[i] > 0)
    #     bcm2835_gpio_write(MOT_B[DIR], step_arrB[i] > 0)
    #
    #     if step_arrA[i] != 0:
    #         bcm2835_gpio_set(MOT_A[STEP])
    #     if step_arrB[i] != 0:
    #         bcm2835_gpio_set(MOT_B[STEP])
    #     retval = read_switches_fast()  # Read switches in the middle of a step
    #                                    # to prolong the width of a step pulse
    #     bcm2835_gpio_clr(MOT_A[STEP])
    #     bcm2835_gpio_clr(MOT_B[STEP])
    #
    #     #Check switches, quit if triggered
    #     if retval:
    #         # print "Switches triggered: " + bin(retval)
    #         break
    #
    #     # # Diagnostic
    #     # gettimeofday(&now, NULL)
    #     # delta = time_diff(then, now)
    #     # opTimes[i] = delta
    #
    #     # Time idle
    #     while delta < time_arr[i]:
    #         gettimeofday(&now, NULL)
    #         delta = time_diff(then, now)
    #
    #     i += 1 #increment for loop
    #
    # bcm2835_gpio_clr(LAS)

    # # Diagnostic
    # errs = [deltaTimes[i+1] - time_list[i] for i in range(list_len-1)]
    # meanErr = sum(errs) / float(len(errs))
    # maxErr = max(errs)
    # minErr = min(errs)
    # std_dev = math.sqrt(sum([(x - meanErr)*(x - meanErr) for x
    #                          in errs]) / float(len(errs)))
    #
    # mean_opTime = sum(opTimes) / list_len
    # std_dev_opTime = math.sqrt(sum([(x - mean_opTime)**2 for x in opTimes])
    #                     / float(list_len))
    # max_opTime = max(opTimes)
    # min_opTime = min(opTimes)
    #
    # print "meanErr: {}, maxErr: {}, minErr: {}, std_dev: {}".format(
    #     meanErr, maxErr, minErr, std_dev)
    # print "mean_opTime: {}, max_opTime: {}, min_opTime: {}, std_dev_opTime: {}"\
    #     .format(mean_opTime, max_opTime, min_opTime, std_dev_opTime)

    return retval

################## INTERNAL HELPER FUNCTIONS ################

cdef inline int time_diff(timeval start, timeval end):
    """ Calculate time in microseconds between 2 timeval structs."""

    return (end.tv_sec - start.tv_sec)*USEC_PER_SEC \
            + (end.tv_usec - start.tv_usec)

cdef int read_switches_fast():
    """ Read values of XY endstop switches and safety feet.

    This is the cdef only version, for faster reads.

    :return: Bitwise 5-bit value for XMIN, XMAX, YMIN, YMAX, SAFE_FEET (LSB)
            (i.e. 0b01001 => 9: YMAX, XMIN)
    :rtype: int
    """
    cdef int retval = 0

    for pin in list_of_sw_pins:
        retval |= (0 if gpioRead(SWS[pin]) else 1 )<< pin

    return retval
