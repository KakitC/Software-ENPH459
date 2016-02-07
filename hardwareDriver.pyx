import math

__author__ = 'Kakit'

import platform
OS = platform.system()
if OS == "Windows":
    print "WARNING: Only written to work for Linux"

import math
from cpython cimport array
import array

# Define external functions
cdef extern from "sys/time.h":
    struct timeval:
        int tv_sec
        int tv_usec
    int gettimeofday(timeval *timer, void *)

# Import bcm2835 c lib functions and vars
cdef extern from "bcm2835.h":
    ctypedef int uint8_t
    ctypedef int uint32_t

    # GPIO init functions
    int bcm2835_init()
    int bcm2835_close()
    void bcm2835_set_debug(uint8_t debug) # Debug only, don't write GPIO, print

    # GPIO functions
    void bcm2835_gpio_fsel(uint8_t pin, uint8_t mode) # Set pin I or O
    void bcm2835_gpio_write(uint8_t pin, uint8_t on) # Write on val to pin
    void bcm2835_gpio_set(uint8_t pin) # Set to 1
    void bcm2835_gpio_clr(uint8_t pin) # Set to 0
    void bcm2835_gpio_set_multi(uint32_t mask) # Set mask bits to 1
    void bcm2835_gpio_clr_multi(uint32_t mask) # Clear mask bits to 0
    uint8_t bcm2835_gpio_lev(uint8_t pin) # Reads pin state (I or O)
    void bcm2835_gpio_set_pud(uint8_t pin, uint8_t pud) # Set pull up/down mode

    # Interrupt register functions
    uint8_t bcm2835_gpio_eds(uint8_t pin) # Checks if pin detects edge event
    uint8_t bcm2835_gpio_set_eds(uint8_t pin) # Writes 1 to clear edge event
    void bcm2835_gpio_ren(uint8_t pin) # Enable Rising edge detect event
    void bcm2835_gpio_clr_ren(uint8_t pin) # Disable Rising edge detect event
    void bcm2835_gpio_fen(uint8_t pin) # Enable Falling edge detect event
    void bcm2835_gpio_clr_fen(uint8_t pin) # Disable Falling edge detect event
    # Not included: Async gpio_aren/afen functions

    void bcm2835_gpio_hen(uint8_t pin) # Enable High detect event
    void bcm2835_gpio_clr_hen(uint8_t pin) # Disable High detect event
    void bcm2835_gpio_len(uint8_t pin) # Enable Low detect event
    void bcm2835_gpio_clr_len(uint8_t pin) # Disable Low detect event

    # Delays depend on nanosleep() wakeup time, like up to 80us
    void bcm2835_delay (unsigned int millis) # Delay millis
    void bcm2835_delayMicroseconds (unsigned int micros) # Delay micros.

    # Not included: SPI functions

    # bcm2835 pinout
    int _RPI_GPIO_P1_03 "RPI_GPIO_P1_03"        # =  0, #
    int _RPI_GPIO_P1_05 "RPI_GPIO_P1_05"        # =  1, #
    int _RPI_GPIO_P1_07 "RPI_GPIO_P1_07"        # =  4, #
    int _RPI_GPIO_P1_08 "RPI_GPIO_P1_08"        # = 14, # defaults alt UART0_TXD
    int _RPI_GPIO_P1_10 "RPI_GPIO_P1_10"        # = 15, # defaults alt UART0_RXD
    int _RPI_GPIO_P1_11 "RPI_GPIO_P1_11"        # = 17, #
    int _RPI_GPIO_P1_12 "RPI_GPIO_P1_12"        # = 18, #
    int _RPI_GPIO_P1_13 "RPI_GPIO_P1_13"        # = 21, #
    int _RPI_GPIO_P1_15 "RPI_GPIO_P1_15"        # = 22, #
    int _RPI_GPIO_P1_16 "RPI_GPIO_P1_16"        # = 23, #
    int _RPI_GPIO_P1_18 "RPI_GPIO_P1_18"        # = 24, #
    int _RPI_GPIO_P1_19 "RPI_GPIO_P1_19"        # = 10, # MOSI when SPI0 in use
    int _RPI_GPIO_P1_21 "RPI_GPIO_P1_21"        # =  9, # MISO when SPI0 in use
    int _RPI_GPIO_P1_22 "RPI_GPIO_P1_22"        # = 25, #
    int _RPI_GPIO_P1_23 "RPI_GPIO_P1_23"        # = 11, # CLK when SPI0 in use
    int _RPI_GPIO_P1_24 "RPI_GPIO_P1_24"        # =  8, # CE0 when SPI0 in use
    int _RPI_GPIO_P1_26 "RPI_GPIO_P1_26"        # =  7, # CE1 when SPI0 in use

    # Port function select modes for bcm2835_gpio_fsel()
    int _GPIO_FSEL_INPT "BCM2835_GPIO_FSEL_INPT "# = 0b000,   ///< Input
    int _GPIO_FSEL_OUTP "BCM2835_GPIO_FSEL_OUTP" # = 0b001,   ///< Output
    # Other definitions
    int HI "HIGH"
    int LO "LOW"

# Define vars
DEF USEC_PER_SEC = 1000000


############# Bind pins to names #############
# MOT_X is an array, with indices enums EN, STEP, DIR
# cdef int EN, STEP, DIR = range(3)

cdef enum MOT_PINS:
    EN       = 0
    STEP     = 1
    DIR      = 2

MOT_A = range(3)
MOT_A[EN]       = _RPI_GPIO_P1_07
MOT_A[STEP]     = _RPI_GPIO_P1_03
MOT_A[DIR]      = _RPI_GPIO_P1_05

MOT_B = range(3)
MOT_B[EN]       = _RPI_GPIO_P1_08
MOT_B[STEP]     = _RPI_GPIO_P1_10
MOT_B[DIR]      = _RPI_GPIO_P1_11

LAS             = _RPI_GPIO_P1_12

# Switches
# End stops
cdef enum ENDSTOP_PINS:
    XMIN    = 0
    XMAX    = 1
    YMIN    = 2
    YMAX    = 3

ENDSTOP = range(4)
ENDSTOP[XMIN]   = _RPI_GPIO_P1_13
ENDSTOP[XMAX]   = _RPI_GPIO_P1_15
ENDSTOP[YMIN]   = _RPI_GPIO_P1_16
ENDSTOP[YMAX]   = _RPI_GPIO_P1_18

# Safety feet E-stop
SAFE_FEET       = _RPI_GPIO_P1_19


############### External Interface Functions ##########################
# Interfaces are def (cpdef?) for Python access

def gpio_init():
    """ Initialize GPIO pins on Raspberry Pi. Make sure to run program
    in "sudo" to allow GPIO to run.
    :return: 0 if success, else 1
    """

    # Init GPIO
    if not bcm2835_init():
        return 1
    # Set output and input pins
    # Outputs
    for outpin in MOT_A + MOT_B:
        bcm2835_gpio_fsel(outpin, _GPIO_FSEL_OUTP)

    # Enable stepper motors
    motor_enable()

    # Inputs
    for inpin in ENDSTOP:
        bcm2835_gpio_fsel(inpin, _GPIO_FSEL_INPT)
    bcm2835_gpio_fsel(SAFE_FEET, _GPIO_FSEL_INPT)
    
    print "GPIO Initialization successful"


def motor_enable():
    """ Set stepper motor Enable pins """
    bcm2835_gpio_set(MOT_A[EN])
    bcm2835_gpio_set(MOT_B[EN])


def motor_disable():
    """ Clear stepper motor Enable pins """
    bcm2835_gpio_clr(MOT_A[EN])
    bcm2835_gpio_clr(MOT_B[EN])


def gpio_close():
    """ Close GPIO connection. Call this when GPIO access is complete.
    :return: void
    """
    bcm2835_close()


def laser_cut(cut_spd, travel_spd, x_start, x_end, y_start, y_end, las_mask,
              step_size):
    """ Perform a single straight-line motion of the laser head
    while firing the laser according to the mask image.

    Laser moves at cut_spd when laser is on, travel_spd else. Uses image bitmap
    from las_mask. Requires gpio_init to be ran first.

    :param cut_spd: Cutting speed in mm/s
    :type: double
    :param travel_spd: Travel speed in mm/s
    :type: double
    :param x_start: X position start in mm
    :type: double
    :param y_start: Y position change in mm
    :type: double
    :param las_mask: Laser engraving bitmap image
    :type: #TODO figure out data format
    """

    #TODO Implement laser_cut()
    # Algorithm:
    # 1. Create pathing step list
    # 1a. Make pixelized line from (x_start,y_start) to (x_end,y_end)
    # 1b. Convert line into a list of A,B coordinates (algo)
    # 2. Create laser spot list from pathing step position vs image
    # 3. Create timing list from speeds and laser spot list
    # 4. Initialize and check things, clear interrupts?
    # 5. Main movement loop, iterate on lists
    # 5a. Step X,Y, set las
    # 5b. Poll switches
    #       if switches: Fail out, throw that exception
    #       # This can just be polled, min speed might be 1mm/s but still
    #       # stepping at 75ms period (13Hz)
    # 5c. Timing idle until next timing delta on list is passed
    # 6. cleanup, return

    # 1. Create pathing step list
    # 1a. Make pixelized line from (x_start,y_start) to (x_end,y_end)

    pass
    #TODO throws exceptions: end stop trigger, safety switch trigger, overtemp
    #TODO Diagnostics (jitter) calcs


cpdef int read_switches():
    """ Read values of XY endstop switches and safety feet.

    :return: Bitwise 5-bit value for XMIN, XMAX, YMIN, YMAX, SAFE_FEET (LSB)
            (i.e. 0b01001 => 9: YMAX, XMIN)
    :rtype: int
    """
    cdef int retval = 0

    for pin in (XMIN, XMAX, YMIN, YMAX):
        retval |= bcm2835_gpio_lev(ENDSTOP[pin]) << pin

    retval |= bcm2835_gpio_lev(SAFE_FEET) << YMAX+1

    return retval

################## INTERNAL HELPER FUNCTIONS ################

def move_laser_wrapper(step_listA, step_listB, las_list, time_list):
    cdef array.array step_arrA = array.array('i', step_listA)
    cdef array.array step_arrB = array.array('i', step_listB)
    cdef array.array las_arr = array.array('i', las_list)
    cdef array.array time_arr = array.array('i', time_list)



#cdef int move_laser(int step_listA[], int step_listB[], int las_list[], int time_list[]):
    """ Perform the laser head step motion loop with precise timings.

    :param step_list: List of [a,b] steps to take each increment. 0 or +/-1.
    :param las_list: List of laser on/off values, same length as step_list. 0/1.
    :param time_list: List of times to spend at each position in us

    :return: Returns associated switch values if endstops or safety feet
    are triggered, else returns 0.
    :rtype: int
    """

    cdef timeval then, now
    cdef int delta = 0
    cdef int retval = 0

    gettimeofday(&then, NULL)
    gettimeofday(&now, NULL)

    # Diagnostics
    # cdef int deltaTimes[len(las_list)]
    # cdef int opTimes[len(las_list)]
    deltaTimes = range(len(las_list))
    opTimes = range(len(las_list))

    for i in range(len(time_list)):
        deltaTimes[i] = delta #Diagnostic

        # Reset times
        then.tv_sec, then.tv_usec = now.tv_sec, now.tv_usec
        delta = 0

        # Set laser
        bcm2835_gpio_write(LAS, las_list[i])

        # Move steppers
        # MOT A DIR positive is X, MOT B DIR positive is Y
        bcm2835_gpio_write(MOT_A[STEP], step_listA[i] != 0)
        bcm2835_gpio_write(MOT_A[DIR], step_listA[i] > 0)

        bcm2835_gpio_write(MOT_B[STEP], step_listB[i] != 0)
        bcm2835_gpio_write(MOT_B[DIR], step_listB[i] > 0)

        #Check switches, quit if triggered
        retval = read_switches()
        if retval:
            print "Switches triggered: " + bin(retval)
            break

        #Diagnostic
        gettimeofday(&now, NULL)
        delta = time_diff(then, now)
        opTimes[i] = delta

        # Time idle
        while delta < time_list[i]:
            gettimeofday(&now, NULL)
            delta = time_diff(then, now)

    bcm2835_gpio_clr(LAS)

    #Diagnostic
    errs = [deltaTimes[i+1] - time_list[i] for i in range(len(time_list)-1)]
    meanErr = sum(errs) / float(len(errs))
    maxErr = max(errs)
    minErr = min(errs)
    std_dev = math.sqrt(sum([(x - meanErr)*(x - meanErr) for x
                             in errs]) / float(len(errs)))

    mean_opTime = sum(opTimes) / len(opTimes)
    std_dev_opTime = math.sqrt(sum([(x - mean_opTime)**2 for x in opTimes])
                        / float(len(opTimes)))
    max_opTime = max(opTimes)
    min_opTime = min(opTimes)

    print "meanErr: {}, maxErr: {}, minErr: {}, std_dev: {}".format(
        meanErr, maxErr, minErr, std_dev)
    print "mean_opTime: {}, max_opTime: {}, min_opTime: {}, std_dev_opTime: {}"\
        .format(mean_opTime, max_opTime, min_opTime, std_dev_opTime)

    return retval


cdef inline int time_diff(timeval start, timeval end):
    """ Calculate time in microseconds between 2 timeval structs."""

    return (end.tv_sec - start.tv_sec)*USEC_PER_SEC \
            + (end.tv_usec - start.tv_usec)
