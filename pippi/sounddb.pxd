#cython: language_level=3


cdef class SoundDB:
    cdef object db
    cdef object c
    cdef str path
