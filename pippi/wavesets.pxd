#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport Wavetable

cdef class Waveset:
    cdef public list wavesets
    cdef public int max_length
    cdef public int min_length
    cdef public int samplerate

    cpdef Waveset copy(Waveset self)
    cdef void _import(Waveset self, list wavesets)
    cdef void _load(Waveset self, object values, double[:] crossings, int offset, int limit, int modulo)
    cpdef void interleave(Waveset self, Waveset source)
    cpdef void normalize(Waveset self, double ceiling=*)
    cpdef void reverse(Waveset self)
    cpdef SoundBuffer replace(Waveset self, object waveforms)
    cpdef Waveset reversed(Waveset self)
    cpdef void retrograde(Waveset self)
    cpdef void invert(Waveset self)
    cdef void _slice(Waveset self, double[:] raw, int start, int end)
    cpdef SoundBuffer substitute(Waveset self, object waveform)
    cpdef SoundBuffer stretch(Waveset self, object factor=*)
    cpdef SoundBuffer harmonic(Waveset self, list harmonics=*, list weights=*)
    cpdef SoundBuffer morph(Waveset self, Waveset target, object curve=*)
    cpdef SoundBuffer render(Waveset self, list wavesets=*, int channels=*, int samplerate=*, int taper=*)
