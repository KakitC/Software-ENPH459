"""
hardwareDriver.pyx
A Cython module for all low-level hardware access functions, containing all
GPIO functions.
"""
__author__ = 'Kakit'

import math
from cpython cimport array

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

    # bcm2835 pinout for Raspberry Pi B+
    # bcm2835 library doesn't support physical pins 27-40
    # (GPIO 5, 6, 12, 13, 19, 26, 20, 21)
    int _RPI_V2_GPIO_P1_03 "RPI_V2_GPIO_P1_03"  # =  2  #Version 2, Pin P1-03
    int _RPI_V2_GPIO_P1_05 "RPI_V2_GPIO_P1_05"  # =  3  #Version 2, Pin P1-05
    int _RPI_V2_GPIO_P1_07 "RPI_V2_GPIO_P1_07"  # =  4  #Version 2, Pin P1-07
    int _RPI_V2_GPIO_P1_08 "RPI_V2_GPIO_P1_08"  # = 14  #Version 2, Pin P1-08, defaults to alt function 0 UART0_TXD
    int _RPI_V2_GPIO_P1_10 "RPI_V2_GPIO_P1_10"  # = 15  #Version 2, Pin P1-10, defaults to alt function 0 UART0_RXD
    int _RPI_V2_GPIO_P1_11 "RPI_V2_GPIO_P1_11"  # = 17  #Version 2, Pin P1-11
    int _RPI_V2_GPIO_P1_12 "RPI_V2_GPIO_P1_12"  # = 18  #Version 2, Pin P1-12
    int _RPI_V2_GPIO_P1_13 "RPI_V2_GPIO_P1_13"  # = 27  #Version 2, Pin P1-13
    int _RPI_V2_GPIO_P1_15 "RPI_V2_GPIO_P1_15"  # = 22  #Version 2, Pin P1-15
    int _RPI_V2_GPIO_P1_16 "RPI_V2_GPIO_P1_16"  # = 23  #Version 2, Pin P1-16
    int _RPI_V2_GPIO_P1_18 "RPI_V2_GPIO_P1_18"  # = 24  #Version 2, Pin P1-18
    int _RPI_V2_GPIO_P1_19 "RPI_V2_GPIO_P1_19"  # = 10  #Version 2, Pin P1-19, MOSI when SPI0 in use
    int _RPI_V2_GPIO_P1_21 "RPI_V2_GPIO_P1_21"  # =  9  #Version 2, Pin P1-21, MISO when SPI0 in use
    int _RPI_V2_GPIO_P1_22 "RPI_V2_GPIO_P1_22"  # = 25  #Version 2, Pin P1-22
    int _RPI_V2_GPIO_P1_23 "RPI_V2_GPIO_P1_23"  # = 11  #Version 2, Pin P1-23, CLK when SPI0 in use
    int _RPI_V2_GPIO_P1_24 "RPI_V2_GPIO_P1_24"  # =  8  #Version 2, Pin P1-24, CE0 when SPI0 in use
    int _RPI_V2_GPIO_P1_26 "RPI_V2_GPIO_P1_26"  # =  7  #Version 2, Pin P1-26, CE1 when SPI0 in use

    # Port function select modes for bcm2835_gpio_fsel()
    int _GPIO_FSEL_INPT "BCM2835_GPIO_FSEL_INPT "# = 0b000,   ///< Input
    int _GPIO_FSEL_OUTP "BCM2835_GPIO_FSEL_OUTP" # = 0b001,   ///< Output
    # Other definitions
    int HI "HIGH"
    int LO "LOW"

# Define vars
cdef int USEC_PER_SEC = 1000000


############# PIN DEFINITIONS #############

# Motor outputs
# MOT_N is an array, with indices enums EN, STEP, DIR
cdef int EN     = 0  # ACTIVE LOW
cdef int STEP   = 1
cdef int DIR    = 2
cdef int[:] list_of_mot_pins = array.array('i', (EN, STEP, DIR))

cdef int MOT_A[3]
MOT_A[EN]       = _RPI_V2_GPIO_P1_03
MOT_A[STEP]     = _RPI_V2_GPIO_P1_05
MOT_A[DIR]      = _RPI_V2_GPIO_P1_07
# GND           = GPIO_09

cdef int MOT_B[3]
MOT_B[EN]       = _RPI_V2_GPIO_P1_08
MOT_B[STEP]     = _RPI_V2_GPIO_P1_10
MOT_B[DIR]      = _RPI_V2_GPIO_P1_12
# GND           = GPIO_14

# Laser output
LAS             = _RPI_V2_GPIO_P1_26

# All input switches
cdef int XMIN       = 0
cdef int XMAX       = 1
cdef int YMIN       = 2
cdef int YMAX       = 3
cdef int SAFE_FEET  = 4
cdef int[:] list_of_sw_pins = array.array('i', (XMIN, XMAX, YMIN, YMAX,
                                                SAFE_FEET))
# Active low
cdef int SWS[5]
SWS[XMIN]   = _RPI_V2_GPIO_P1_13
SWS[XMAX]   = _RPI_V2_GPIO_P1_15
# Vcc (3V3) = GPIO_17
SWS[YMIN]   = _RPI_V2_GPIO_P1_21
SWS[YMAX]   = _RPI_V2_GPIO_P1_19  # woops wires
SWS[SAFE_FEET] = _RPI_V2_GPIO_P1_23  # woops active hi by accident
# GND       = GPIO_25

############### External Interface Functions ##########################

cpdef int gpio_init():
    """ Initialize GPIO pins on Raspberry Pi. Make sure to run program
    in "sudo" to allow GPIO to run.

    :return: 0 if success, else 1
    """

    # Init GPIO
    if not bcm2835_init():
        return 1
    # Set output and input pins
    # Outputs
    for outpin in list_of_mot_pins:
        bcm2835_gpio_fsel(MOT_A[outpin], _GPIO_FSEL_OUTP)
        bcm2835_gpio_fsel(MOT_B[outpin], _GPIO_FSEL_OUTP)

    # Inputs
    for inpin in list_of_sw_pins:
        bcm2835_gpio_fsel(SWS[inpin], _GPIO_FSEL_INPT)
    
    #print "GPIO Initialization successful"
    return 0


cpdef void gpio_close():
    """ Close GPIO connection. Call this when GPIO access is complete.

    :return: void
    """

    bcm2835_close()


cpdef void gpio_test():
    """ Toggles all mot pins at max speed for 5s

    :return: void
    """

    gpio_init()

    cdef timeval now, then
    gettimeofday(&then, NULL)
    gettimeofday(&now, NULL)
    while time_diff(then, now) < 5*USEC_PER_SEC:
        for pin in list_of_mot_pins:
            bcm2835_gpio_set(MOT_A[pin])
            bcm2835_gpio_set(MOT_B[pin])
        bcm2835_gpio_set(LAS)

        for pin in list_of_mot_pins:
            bcm2835_gpio_clr(MOT_A[pin])
            bcm2835_gpio_clr(MOT_B[pin])
        bcm2835_gpio_clr(LAS)


cpdef void motor_enable():
    """ Set stepper motor Enable pins

    :return: void
    """

    # Active low
    bcm2835_gpio_clr(MOT_A[EN])
    bcm2835_gpio_clr(MOT_B[EN])


cpdef void motor_disable():
    """ Clear stepper motor Enable pins

    :return: void
    """

    # Active low
    bcm2835_gpio_set(MOT_A[EN])
    bcm2835_gpio_set(MOT_B[EN])


cpdef void las_pulse(double time):
    """ Turn on the laser output for a given time, then turn off.

    For testing laser functionality. Don't have a function allowing raw access
    to laser GPIO, meaning accidentally leaving it on indefinitely.

    :param time: Pulse length in seconds
    :type: int
    :return: void
    """

    bcm2835_gpio_set(LAS)
    time.sleep(time)
    bcm2835_gpio_clr(LAS)


cpdef int read_switches():
    """ Read values of XY endstop switches and safety feet.

    This is the sensor interface version of the function.

    :return: Bitwise 5-bit value for XMIN, XMAX, YMIN, YMAX, SAFE_FEET (LSB)
            (i.e. 0b01001 => 9: YMAX, XMIN)
    :rtype: int
    """
    cdef int retval = 0

    for pin in list_of_sw_pins:
        retval |= (0 if bcm2835_gpio_lev(SWS[pin]) else 1 )<< pin

    return retval


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

    # # Diagnostics
    # cdef int[:] deltaTimes = array.array('i', range(list_len))
    # cdef int[:] opTimes = array.array('i', range(list_len))

    cdef int i = 0
    while i < list_len:
        # # Diagnostic
        # deltaTimes[i] = delta

        # Reset times
        then.tv_sec, then.tv_usec = now.tv_sec, now.tv_usec
        delta = 0

        # Set laser
        bcm2835_gpio_write(LAS, las_arr[i])
        # bcm2835_gpio_write(LAS, 1 if las_arr[i] else 0)  # 8b power settings

        # Move steppers
        # MOT A DIR positive is _, MOT B DIR positive is _
        bcm2835_gpio_write(MOT_A[DIR], step_arrA[i] > 0)
        bcm2835_gpio_write(MOT_B[DIR], step_arrB[i] > 0)

        if step_arrA[i] != 0:
            bcm2835_gpio_set(MOT_A[STEP])
        if step_arrB[i] != 0:
            bcm2835_gpio_set(MOT_B[STEP])
        retval = read_switches_fast()  # Read switches in the middle of a step
                                       # to prolong the width of a step pulse
        bcm2835_gpio_clr(MOT_A[STEP])
        bcm2835_gpio_clr(MOT_B[STEP])

        #Check switches, quit if triggered
        if retval:
            # print "Switches triggered: " + bin(retval)
            break

        # # Diagnostic
        # gettimeofday(&now, NULL)
        # delta = time_diff(then, now)
        # opTimes[i] = delta

        # Time idle
        while delta < time_arr[i]:
            gettimeofday(&now, NULL)
            delta = time_diff(then, now)

        i += 1 #increment for loop

    bcm2835_gpio_clr(LAS)

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
        retval |= (0 if bcm2835_gpio_lev(SWS[pin]) else 1 )<< pin

    return retval
