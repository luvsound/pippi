#cython: language_level=3

from pippi.wavetables cimport Wavetable
from pippi.soundbuffer cimport SoundBuffer

cdef double[:,:] _norm(double[:,:] snd, double ceiling)
cpdef SoundBuffer norm(SoundBuffer snd, double ceiling)

cdef double[:,:] _fir(double[:,:] snd, double[:,:] out, double[:] impulse, bint norm=*)
cpdef SoundBuffer fir(SoundBuffer snd, object impulse, bint normalize=*)

cdef double _fold_point(double sample, double last, double samplerate)
cdef double[:,:] _fold(double[:,:] out, double[:,:] snd, double[:] amp, double samplerate)
cpdef SoundBuffer fold(SoundBuffer snd, object amp=*, bint norm=*)

cpdef Wavetable envelope_follower(SoundBuffer snd, double window=*)
cpdef SoundBuffer widen(SoundBuffer snd, object width=*)

cdef double[:,:] _softclip(double[:,:] out, double[:,:] snd) nogil
cpdef SoundBuffer softclip(SoundBuffer snd)

ctypedef void (*svf_filter_t)(SVFData* data) 

ctypedef struct SVFData:
    double[4] Az 
    double[2] Bz
    double[3] Cz
    double[2] X

    double[3] M
    double freq
    double res
    double gain
    double shelf

cpdef SoundBuffer hpf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer lpf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer bpf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer notchf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer peakf(SoundBuffer snd, object freq=*, object res=*, bint norm=*)

cpdef SoundBuffer belleq(SoundBuffer snd, object freq=*, object q=*, object gain=*, bint norm=*)
cpdef SoundBuffer lshelfeq(SoundBuffer snd, object freq=*, object q=*, object gain=*, bint norm=*)
cpdef SoundBuffer hshelfeq(SoundBuffer snd, object freq=*, object q=*, object gain=*, bint norm=*)

cpdef SoundBuffer buttlpf(SoundBuffer snd, object freq)
cpdef SoundBuffer butthpf(SoundBuffer snd, object freq)
cpdef SoundBuffer buttbpf(SoundBuffer snd, object freq)
cpdef SoundBuffer brf(SoundBuffer snd, object freq)
