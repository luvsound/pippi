#cython: language_level=3

from pippi.interpolation cimport interp_pos_t

from pippi.soundbuffer cimport SoundBuffer

cdef class Tukey:
    cdef public double[:] shape
    cdef public double[:] freq
    cdef public double[:] amp

    cdef double phase

    cdef public int channels
    cdef public int samplerate

    cdef interp_pos_t freq_interpolator

    cpdef SoundBuffer play(Tukey self, double length=*)

