#cython: language_level=3


cdef double _hermite_pos(double[:] data, double pos) nogil
cdef double _hermite_point_pw(double[:] data, double phase, double pulsewidth) nogil
cdef double _hermite_point(double[:] data, double phase) nogil

cdef double _linear_point_pw(double[:] data, double phase, double pulsewidth) nogil
cdef double _linear_point(double[:] data, double phase) nogil
cpdef double linear_point(double[:] data, double phase, double pulsewidth=*)

cdef double _linear_pos(double[:] data, double pos) nogil
cpdef double linear_pos(double[:] data, double pos)
cdef double[:] _linear(double[:] data, int length)
cpdef double[:] linear(object data, int length)

cdef double _trunc_point(double[:] data, double pos) nogil
cpdef double trunc_point(double[:] data, double phase)
cdef double _trunc_pos(double[:] data, double pos) nogil
cpdef double trunc_pos(double[:] data, double pos)
cdef double[:] _trunc(double[:] data, int length)
cpdef double[:] trunc(object data, int length)

# Use these for function pointers in critical loops 
# when interpolation scheme can be set at runtime
ctypedef double (*interp_point_t)(double[:] data, double phase) nogil
ctypedef double (*interp_point_pw_t)(double[:] data, double phase, double pulsewidth) nogil
ctypedef double (*interp_pos_t)(double[:] data, double pos) nogil

cdef interp_point_t get_point_interpolator(str flag)
cdef interp_pos_t get_pos_interpolator(str flag)

cdef class Bandlimit:

    cdef int quality
    cdef int samples_per_0x
    cdef int filter_length
    cdef double[:] filter_table
    cdef int table_length
    cdef double[:] table

    cdef void _make_filter(self)
    cdef double _get_filter_coeff(self, double phase) nogil
    cdef double _process_loop(self, double phase, double resampling_factor) nogil

    cpdef double process(self, double phase, double resampling_factor)
