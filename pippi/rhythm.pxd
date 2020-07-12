#cython: language_level=3

from pippi.wavetables cimport Wavetable

cdef class Seq:
    cdef double[:] beat
    cdef public dict drums


