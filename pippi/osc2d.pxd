#cython: language_level=3

from pippi.interpolation cimport interp_point_t

cdef class Osc2d:
    cdef public double[:] freq
    cdef public double[:] amp

    cdef interp_point_t freq_interpolator

    cdef list wavetables
    cdef public double lfo_freq
    cdef object lfo

    cdef double[:] window
    cdef public double pulsewidth

    cdef double[:] mod
    cdef public double mod_range
    cdef public double mod_freq

    cdef public double phase
    cdef public double win_phase
    cdef public double mod_phase
    cdef double freq_phase
    cdef double amp_phase

    cdef public int channels
    cdef public int samplerate
    cdef public int wtsize

    cdef object _play2d(self, int length)
