#cython: language_level=3

from pippi.wavetables cimport Wavetable

cdef double[:,:] sb_adsr(double[:,:] frames, int framelength, int channels, double samplerate, double attack, double decay, double sustain, double release) nogil
cdef double[:,:] _speed(double[:,:] frames, double[:,:] out, double[:] chan, double[:] outchan, int channels) nogil
cdef double[:,:] _dub(double[:,:] target, int target_length, double[:,:] todub, int todub_length, int channels, int framepos) nogil
cdef double[:,:] _pan(double[:,:] out, int length, int channels, double[:] pos, int method)

cdef class SoundBuffer:
    cdef public int samplerate
    cdef public int channels
    cdef public double[:,:] frames

    cdef void _dub(SoundBuffer self, SoundBuffer sound, int framepos)
    cdef void _fill(SoundBuffer self, double[:,:] frames)
    cpdef SoundBuffer adsr(SoundBuffer self, double a=*, double d=*, double s=*, double r=*)
    cpdef SoundBuffer convolve(SoundBuffer self, object impulse, bint norm=*)
    cpdef SoundBuffer pan(SoundBuffer self, object pos=*, str method=*)
    cpdef SoundBuffer stretch(SoundBuffer self, double length, object position=*, double amp=*)
    cpdef SoundBuffer transpose(SoundBuffer self, object speed, object length=*, object position=*, double amp=*)
    cpdef SoundBuffer trim(SoundBuffer self, bint start=*, bint end=*, double threshold=*, int window=*)
    cpdef Wavetable toenv(SoundBuffer self, double window=*)
    cpdef SoundBuffer vspeed(SoundBuffer self, object speed)


