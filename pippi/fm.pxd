#cython: language_level=3

from pippi.interpolation cimport interp_point_t

cdef class FM:
    cdef public double[:] freq
    cdef public double[:] ratio
    cdef public double[:] index 
    cdef public double[:] amp
    cdef public double[:] carrier
    cdef public double[:] modulator

    cdef interp_point_t freq_interpolator

    cdef double freq_phase
    cdef double ratio_phase
    cdef double index_phase
    cdef double amp_phase
    cdef double cwt_phase
    cdef double mwt_phase

    cdef public int channels
    cdef public int samplerate
    cdef public int wtsize

    cdef object _play(self, int length)
