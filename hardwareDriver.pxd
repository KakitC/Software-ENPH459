cdef int USEC_PER_SEC

cdef int EN, STEP, DIR
cdef int[:] list_of_mot_pins
cdef int XMIN, XMAX, YMIN, YMAX, SAFE_FEET
cdef int[:] list_of_sw_pins

cpdef int gpio_init()
cpdef void gpio_close()
cpdef void motor_enable()
cpdef void motor_disable()
cpdef void las_pulse(double time)
cpdef int read_switches()
cdef int move_laser(step_list, las_list, time_list)
