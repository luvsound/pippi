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

ctypedef struct BLIData:
    int quality
    int samples_per_0x
    int filter_length
    int table_length
    int wrap
    double* filter_table
    double* table

cdef BLIData* _bli_init(double[:] data, int quality, bint loop)
cdef double _bli_pos(BLIData* data, double pos, double resampling_factor) nogil
cdef double _bli_point(BLIData* data, double point, double resampling_factor) nogil





