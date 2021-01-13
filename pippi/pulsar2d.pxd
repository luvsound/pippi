#cython: language_level=3

from pippi.interpolation cimport interp_point_t

cdef class Pulsar2d:
    cdef public double[:] freq
    cdef public double[:] amp
    cdef public double[:] pulsewidth

    cdef public double[:] mask
    cdef public long[:] burst

    cdef double[:,:] wavetables
    cdef double[:,:] windows

    cdef interp_point_t freq_interpolator

    cdef int wt_count
    cdef int wt_length
    cdef double wt_pos
    cdef double wt_phase
    cdef double wt_mod_phase
    cdef double[:] wt_mod

    cdef int win_count
    cdef int win_length
    cdef double win_pos
    cdef double win_phase
    cdef double win_mod_phase
    cdef double[:] win_mod

    cdef double freq_phase
    cdef double pw_phase
    cdef double amp_phase
    cdef double mask_phase
    cdef double burst_phase
    cdef int burst_length

    cdef public int channels
    cdef public int samplerate

    cdef object _play(self, int length)
