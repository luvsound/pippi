#cython: language_level=3

#from pippi.ugens.core cimport ugen_t

cdef class Cloud:
    cdef double[:,:] snd
    cdef unsigned int framelength
    cdef double length
    cdef unsigned int channels
    cdef unsigned int samplerate

    cdef unsigned int wtsize

    cdef double[:] window
    cdef double[:] position
    cdef double[:] amp
    cdef double[:] speed
    cdef double[:] spread
    cdef double[:] jitter
    cdef double[:] grainlength
    cdef double[:] grid

    cdef int[:] mask
    cdef bint has_mask

