#cython: language_level=3

from pippi.wavetables cimport Wavetable
from pippi.soundbuffer cimport SoundBuffer

cdef double[:,:] _norm(double[:,:] snd, double ceiling)
cdef double[:,:] _fir(double[:,:] snd, double[:,:] out, double[:] impulse, bint norm=*)
cpdef SoundBuffer fir(SoundBuffer snd, object impulse, bint normalize=*)

cdef double _fold_point(double sample, double last, double samplerate)
cdef double[:,:] _fold(double[:,:] out, double[:,:] snd, double[:] amp, double samplerate)
cpdef SoundBuffer fold(SoundBuffer snd, object amp=*, bint norm=*)

cpdef Wavetable envelope_follower(SoundBuffer snd, double window=*)
cpdef SoundBuffer widen(SoundBuffer snd, object width=*)

cdef double[:,:] _softclip(double[:,:] out, double[:,:] snd) nogil
cpdef SoundBuffer softclip(SoundBuffer snd)

ctypedef double (*svf_filter_t)(SVFData* data, double val) 

ctypedef struct SVFData:
    double[4] Az 
    double[2] Bz
    double[2] X

    double a1
    double a2
    double a3
    double g
    double k

cpdef SoundBuffer hpf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer lpf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer bpf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)

cpdef SoundBuffer buttlpf(SoundBuffer snd, object freq)
cpdef SoundBuffer butthpf(SoundBuffer snd, object freq)
cpdef SoundBuffer buttbpf(SoundBuffer snd, object freq)
cpdef SoundBuffer brf(SoundBuffer snd, object freq)
