#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

cdef class Event:
    cdef public double onset
    cdef public double length
    cdef public double freq
    cdef public double amp
    cdef public double pos
    cdef public int count
    cdef public dict _params
    cdef public object _before

cdef SoundBuffer render(list events, object callback, int channels, int samplerate)
