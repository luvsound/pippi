#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

cdef class Tukey:
    cdef double phase

    cdef public int channels
    cdef public int samplerate

    cpdef SoundBuffer play(Tukey self, double length=*, object freq=*, object shape=*)

