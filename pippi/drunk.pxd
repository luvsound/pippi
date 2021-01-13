#cython: language_level=3

from pippi.interpolation cimport interp_point_t

cdef class Drunk:
    cdef public double[:] freq
    cdef public double[:] width
    cdef public double[:] amp
    cdef public double[:] wavetable

    cdef interp_point_t freq_interpolator

    cdef double freq_phase
    cdef double width_phase
    cdef double amp_phase
    cdef double wt_phase

    cdef public int channels
    cdef public int samplerate
    cdef public int numpoints
    cdef public int wtsize

    cdef object _play(self, int length)
