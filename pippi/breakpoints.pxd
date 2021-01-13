#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

ctypedef struct Point:
    double x # 0 - 1 relative position inside buffer/table
    double y # -1 - 1 absolute magnitude


cdef class Breakpoint:
    cdef Point* points
    cdef double[:] out
    cdef int wtsize
    cdef int numpoints

