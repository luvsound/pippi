#cython: language_level=3

from pippi.interpolation cimport interp_point_t

cdef class Pulsar:
    cdef public double[:] freq
    cdef public double[:] amp
    cdef public double[:] wavetable
    cdef public double[:] window
    cdef public double[:] pulsewidth

    cdef interp_point_t freq_interpolator

    cdef public double[:] mask
    cdef public long[:] burst

    cdef double wt_phase
    cdef double win_phase
    cdef double freq_phase
    cdef double pw_phase
    cdef double amp_phase
    cdef double mask_phase
    cdef double burst_phase
    cdef int burst_length

    cdef public int channels
    cdef public int samplerate

    cdef object _play(self, int length)
