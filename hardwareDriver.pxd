cdef int USEC_PER_SEC

cdef int EN, STEP, DIR
cdef int[:] list_of_mot_pins
cdef int XMIN, XMAX, YMIN, YMAX, SAFE_FEET
cdef int[:] list_of_sw_pins

cdef int gpio_init()
cdef void gpio_close()
cdef void motor_enable()
cdef void motor_disable()
cdef int read_switches()
cdef int move_laser(step_list, las_list, time_list)
