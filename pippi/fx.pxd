#cython: language_level=3

from pippi.wavetables cimport Wavetable
from pippi.soundbuffer cimport SoundBuffer

cdef double[:,:] _norm(double[:,:] snd, double ceiling)
cdef double[:,:] _fir(double[:,:] snd, double[:,:] out, double[:] impulse, bint norm=*)
cpdef SoundBuffer fir(SoundBuffer snd, object impulse, bint normalize=*)
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

cpdef SoundBuffer svf_hp(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer svf_lp(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
cpdef SoundBuffer svf_bp(SoundBuffer snd, object freq=*, object res=*, bint norm=*)
