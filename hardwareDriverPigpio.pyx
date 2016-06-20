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

    unsigned gpioVersion()  # version number

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
    int gpioWaveDelete(unsigned wave_id)
    int gpioWaveGetPulses()
    int gpioWaveGetHighPulses()
    int gpioWaveGetMaxPulses()
    int gpioWaveGetCbs()
    int gpioWaveGetHighCbs()
    int gpioWaveGetMaxCbs()
    int gpioWaveGetMicros()
    int gpioWaveGetHighMicros()
    int gpioWaveGetMaxMicros()

    # Not included: SPI functions, I2C, serial

    # GPIO Wave sending functions
    int gpioWaveTxSend(unsigned wave_id, unsigned wave_mode)
    int gpioWaveChain(char *buf, unsigned bufSize)
    int gpioWaveTxAt()
    int gpioWaveTxBusy()
    int gpioWaveTxStop()

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

cdef int PI_WAVE_MODE_ONE_SHOT      = 0
cdef int PI_WAVE_MODE_REPEAT        = 1
cdef int PI_WAVE_MODE_ONE_SHOT_SYNC = 2
cdef int PI_WAVE_MODE_REPEAT_SYNC   = 3

############# PIN DEFINITIONS #############
# pigpio uses BCM pin numbering, not physical

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

# Note: In future use, UI buttons are distinct from switches. Switches/sw/sws
# are hardware interrupt safety features, buttons/butt/butts are non-critical
# and not polled all the time.
cdef int switch_pin_mask = 0
for pin in list_of_sw_pins:
    assert pin < 32
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
    gpioWrite_Bits_0_31_Clear(output_pin_mask)

    # Inputs
    for inpin in list_of_sw_pins:
        gpioSetMode(SWS[inpin], GPIO_INPUT)
    
    #print "GPIO Initialization successful"
    return 0


cpdef void gpio_close():
    """ Close GPIO connection. Call this when GPIO access is complete.

    :return: void
    """

    # Clear all pins
    gpioWrite_Bits_0_31_Clear(output_pin_mask)

    gpioTerminate()


cpdef void gpio_test():
    """ Toggles all mot pins rapidly for 5s. DON'T call this while things are
    connected to the pins!

    :return: void
    """

    gpio_init()

    cdef timeval now, then
    gettimeofday(&then, NULL)
    gettimeofday(&now, NULL)
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
    cdef int gpio_bits = 0
    gpio_bits = gpioRead_Bits_0_31()
    # Get input pin from 32b to enumerated position: 1 << (0 to 5)
    for pin in list_of_sw_pins:
        retval += (gpio_bits && (1 << SWS[pin])) << pin
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

    # Memory alloc
    cdef gpioPulse_t *delay_pulse
    cdef gpioPulse_t *step_pulse1
    cdef gpioPulse_t *step_pulse2
    mem = Pool()
    delay_pulse = <gpioPulse_t*> mem.alloc(1, sizeof(gpioPulse_t))
    step_pulse1 = <gpioPulse_t*> mem.alloc(1, sizeof(gpioPulse_t))
    step_pulse2 = <gpioPulse_t*> mem.alloc(1, sizeof(gpioPulse_t))

    # Build gpioWave
    cdef int i = 0
    cdef delay = 0
    delay_pulse.gpioOff = 0
    delay_pulse.gpioOn = 0
    while i < len(las_list):
        delay_pulse.usDelay = delay

        # Build step pulses: (EN, DIR, STEP)x2, LAS
        step_pulse1.gpioOn = (1 << MOT_A[EN]) | (1 << MOT_B[EN]) \
                             | ((step_arrA[i] > 0) << MOT_A[DIR]) \
                             | ((step_arrB[i] > 0) << MOT_B[DIR]) \
                             | ((step_arrA[i] != 0) << MOT_A[STEP]) \
                             | ((step_arrB[i] != 0) << MOT_B[STEP]) \
                             | ((las_arr[i] != 0) << LAS)
        step_pulse1.gpioOff = ((step_arrA[i] < 0) << MOT_A[DIR]) \
                             | ((step_arrB[i] < 0) << MOT_B[DIR]) \
                             | ((las_arr[i] == 0) << LAS)
        step_pulse1.usDelay = int(time_arr[i] / 2)

        step_pulse2.gpioOn = step_pulse1.gpioOn
        step_pulse2.gpioOn &= ~((1 << MOT_A[STEP]) | (1 << MOT_B[STEP]))
        step_pulse2.gpioOff = step_pulse1.gpioOff
        step_pulse2.gpioOff &= (1 << MOT_A[STEP]) | (1 << MOT_B[STEP])
        step_pulse2.usDelay = time_arr[i] - step_pulse1.usDelay

        gpioWaveAddGeneric(3, [delay_pulse[0], step_pulse1[0], step_pulse2[0]])

        delay += time_arr[i]
        i += 1

    delay_pulse.usDelay = delay
    step_pulse1.gpioOn = (1 << MOT_A[EN]) | (1 << MOT_B[EN])  # just in case
    step_pulse1.gpioOff =  (1 << LAS)

    cdef int wave_id = gpioWaveCreate()
    # TODO Check with gpioWaveTxBusy if there's a wave already going
    #gpioWaveTxSend(wave_id, PI_WAVE_MODE_ONE_SHOT)

    # Poll switches
    # If switch was hit: get switch state, stop current operation, stop laser
    cdef int retval = 0
    while gpioWaveTxBusy():
        if read_switches_fast():
            retval = read_switches()
            gpioWaveTxStop()
            gpioWrite(LAS, LO)
            # has a chance of stopping halfway through a step
            gpioWrite(MOT_A[STEP], LO)
            gpioWrite(MOT_B[STEP], LO)
            break

    gpioWaveDelete(wave_id)  # clean memory, gpioPulses dealloc themselves
    # TODO Debug with print statements but don't actually output GPIO

    return retval

################## INTERNAL HELPER FUNCTIONS ################

cdef inline int time_diff(timeval start, timeval end):
    """ Calculate time in microseconds between 2 timeval structs. Deprecated."""

    return (end.tv_sec - start.tv_sec)*USEC_PER_SEC \
            + (end.tv_usec - start.tv_usec)


cdef int read_switches_fast():
    """ Checks if any of the switches were pressed. Only returns true or false
    for speed.

    :return: True if a switch was pressed, otherwise false
    :rtype: int
    """

    return gpioRead_Bits_0_31() && switch_pin_mask
