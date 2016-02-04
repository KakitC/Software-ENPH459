import math

__author__ = 'Kakit'

import platform
OS = platform.system()
if OS == "Windows":
    print "WARNING: Only written to work for Linux"

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
    int _GPIO_FSEL_INPT = "BCM2835_GPIO_FSEL_INPT "# = 0b000,   ///< Input
    int _GPIO_FSEL_OUTP = "BCM2835_GPIO_FSEL_OUTP" # = 0b001,   ///< Output
    # Other definitions
    int HI "HIGH"
    int LO "LOW"

# Define vars
DEF USEC_PER_SEC = 1000000


############# Bind pins to names #############
# MOT_X is an array, with indices enums EN, STEP, DIR
cdef int EN, STEP, DIR = range(3)

MOT_A = []
MOT_A[EN]       = _RPI_GPIO_P1_07
MOT_A[STEP]     = _RPI_GPIO_P1_03
MOT_A[DIR]      = _RPI_GPIO_P1_05

MOT_B = []
MOT_B[EN]       = _RPI_GPIO_P1_08
MOT_B[STEP]     = _RPI_GPIO_P1_10
MOT_B[DIR]      = _RPI_GPIO_P1_11

# Switches
# End stops
cdef int XMIN, XMAX, YMIN, YMAX = range(4)
ENDSTOP = []
ENDSTOP[XMIN]   = _RPI_GPIO_P1_12
ENDSTOP[XMAX]   = _RPI_GPIO_P1_13
ENDSTOP[YMIN]   = _RPI_GPIO_P1_15
ENDSTOP[YMAX]   = _RPI_GPIO_P1_16

# Safety feet E-stop
SAFE_FEET       = _RPI_GPIO_P1_18


############### External Interface Functions ##########################
# All helper funcs are cdef, interfaces are def (cpdef?)

def gpio_init():
    """ Initializes GPIO pins on Raspberry Pi. Make sure to run program
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

    # Inputs
    for inpin in ENDSTOP:
        bcm2835_gpio_fsel(inpin, _GPIO_FSEL_INPT)
    bcm2835_gpio_fsel(SAFE_FEET, _GPIO_FSEL_INPT)


def gpio_close():
    """ Closes GPIO connection. Call this when GPIO access is complete.
    :return: void
    """
    bcm2835_close()


def laser_cut(cut_spd, travel_spd, x_start, x_end, y_start, y_end, las_mask):
    """ Performs a single straight-line motion of the laser head
    while firing the laser according to the mask image.

    Laser moves at cut_spd when laser is on, travel_spd else. Uses image bitmap
    from las_mask. Requires gpio_init to be
    ran first.

    :param cut_spd: Cutting speed in mm/s
    :type: double
    :param travel_spd: Travel speed in mm/s
    :type: double
    :param x_delta: X position change in mm
    :type: double
    :param y_delta: Y position change in mm
    :type: double
    :param las_mask: Laser engraving bitmap image
    :type: #TODO figure out data format
    """
    # # This function will be called often, don't grab the image every time
    #
    # 1. Create pathing step list
    # 2. Create laser spot list from pathing step position vs image
    # 3. Create timing list from speeds and laser spot list
    # 4. Initialize and check things, clear interrupts?
    # 5. Main movement loop, iterate on lists
    # 5a. Step X,Y, set las
    # 5b. Check switches
    #       if switches: Fail out, throw that exception
    # 5c. Timing idle until next timing delta on list is passed
    #
    # 6. cleanup, return

    pass
    #TODO Implement laser_cut()
    #TODO throws exceptions: end stop trigger, safety switch trigger, overtemp
    #TODO Diagnostics (jitter) calcs


################## INTERNAL HELPER FUNCTIONS ################

#TODO Change to interrupt based
cdef bool read_switches():
    """ Checks if any switches are active during normal operation.

    Safety feet are on if any switch is UNPRESSED. Hardwired together.

    :return: True if any switch is active, else False
    :rtype: bool
    """
    if bcm2835_gpio_lev(SAFE_FEET):
        return True

    if read_endstops() > 0:
        return True

    return False

#TODO This seems more like a sensor interface function, not for normal operation
cdef int read_endstops():
    """ Reads values of XY endstop switches.

    :return: Bitwise 4-bit value for XMIN, XMAX, YMIN, YMAX (0b1001 => 9)
    :rtype: int
    """
    cdef int retval = 0
    for pin in range(len(ENDSTOP)):
        retval += bcm2835_gpio_lev(ENDSTOP[pin]) << pin
    return retval