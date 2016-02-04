import math

__author__ = 'kakit'

import platform
OS = platform.system()
if OS == "Windows":
    print "WARNING: Only written to work for Linux"

from time import sleep

cdef extern from "sys/time.h":
    struct timeval:
        int tv_sec
        int tv_usec
    int gettimeofday(timeval *timer, void *)

cdef extern from "bcm2835.h":
    ctypedef int uint8_t
    int bcm2835_init()
    int bcm2835_close()
    void bcm2835_gpio_write(uint8_t pin, uint8_t on)
    void bcm2835_gpio_fsel(uint8_t pin, uint8_t mode)

    int _BCM2835_GPIO_FSEL_OUTP "BCM2835_GPIO_FSEL_OUTP"
    int _RPI_GPIO_P1_11 "RPI_GPIO_P1_11"
    int HI "HIGH"
    int LO "LOW"

DEF USEC_PER_SEC = 1000000
PIN = _RPI_GPIO_P1_11

cdef int timeDiff(timeval start, timeval end):
    return (end.tv_sec - start.tv_sec)*USEC_PER_SEC \
            + (end.tv_usec - start.tv_usec)

def gpioInit():
    #Init GPIO
    if not bcm2835_init():
        return 1
    # Set the pin to be an output
    bcm2835_gpio_fsel(PIN, _BCM2835_GPIO_FSEL_OUTP)

def gpioClose():
    bcm2835_close()

def freqTest():
    cdef timeval start, end
    cdef int count = 0
    cdef int delta

    print "Starting"

    gettimeofday(&start, NULL)
    gettimeofday(&end, NULL)
    delta = timeDiff(start, end)
    while delta < USEC_PER_SEC:
        bcm2835_gpio_write(PIN, HI)
        bcm2835_gpio_write(PIN, LO)
        count += 1
        gettimeofday(&end, NULL)
        delta = timeDiff(start, end)

    delta = timeDiff(start, end)
    print "Delta {}us".format(delta)
    freq = (1.0 * count) / delta
    print "Freq {}MHz".format(freq)


def jitterTest():
    cdef int testTime = 1 * USEC_PER_SEC
    cdef int targetFreq = 4000
    cdef int targetPeriod = USEC_PER_SEC / targetFreq
    toggles = (int) (targetFreq * USEC_PER_SEC * 1.0) / testTime
    cdef int toggleIters = 4000

    cdef timeval start, end
    cdef int saveTime[4000]
    cdef int delta = 0
    cdef int count = 0

    print "testTime {}, targetFreq {}, targetPeriod {}, toggleIters {}\n".format(
        testTime, targetFreq, targetPeriod, toggleIters)

    gettimeofday(&start, NULL)

    while delta < testTime:
        gettimeofday(&end, NULL)
        delta = timeDiff(start, end)

        if delta > count * targetPeriod:
            bcm2835_gpio_write(PIN, HI)
            bcm2835_gpio_write(PIN, LO)

            gettimeofday(&end, NULL)
            delta = timeDiff(start, end)
            saveTime[count] = delta
            count += 1

    print "Step iteration precision at {}Hz in {}us, count: {}".format(
        targetFreq, testTime, count)

    errTime = [saveTime[x] - ((x+1.0) * testTime / toggleIters)
               for x in range(len(saveTime))]
    errTime = [0 if x < 0 else x for x in errTime]

    print "Ex. Errors, max, min: ", errTime[100:101], ", ", max(errTime), \
        ", " , min(errTime), "..."

    mean = sum(errTime) / count
    print "Average error: ", mean

    std_dev = math.sqrt(sum([(x - mean)**2 for x in errTime])/len(errTime))
    print "Standard deviation: ", std_dev

    qosCutoff = 30
    qosCount = sum([1 if x > qosCutoff else 0 for x in errTime])
    print "Err count above {}us {}".format(qosCutoff, qosCount)

