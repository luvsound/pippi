#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

cdef class Bar:
    cdef public double[:] amp
    cdef public double decay
    cdef public double stiffness
    cdef public double leftclamp
    cdef public double rightclamp
    cdef public double scan
    cdef public double barpos
    cdef public double velocity
    cdef public double width
    cdef public double loss

    cdef public int channels
    cdef public int samplerate
    cdef public int wtsize

    cdef SoundBuffer _play(self, int length)
