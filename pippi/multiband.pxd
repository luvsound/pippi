#cython: language_level=3
#clib soundpipe

from pippi.soundbuffer cimport SoundBuffer
from libc.stdint cimport uint32_t, int64_t

cdef extern from "soundpipe.h":
    ctypedef struct sp_data:
        double* out;
        int sr
        int nchan
        unsigned long len
        unsigned long pos
        char filename[200]
        uint32_t rand

    int sp_create(sp_data**)
    int sp_destroy(sp_data**)
    int sp_process(sp_data*, void*, void (*callback)(sp_data*, void*))

    ctypedef struct sp_butlp:
        double sr, freq, istor
        double lkf
        double a[8]
        double pidsr

    int sp_butlp_create(sp_butlp**)
    int sp_butlp_destroy(sp_butlp**)
    int sp_butlp_init(sp_data*, sp_butlp*)
    int sp_butlp_compute(sp_data*, sp_butlp*, double*, double*)

    ctypedef struct sp_buthp:
        double sr, freq, istor
        double lkf
        double a[8]
        double pidsr

    int sp_buthp_create(sp_buthp**)
    int sp_buthp_destroy(sp_buthp**)
    int sp_buthp_init(sp_data*, sp_buthp*)
    int sp_buthp_compute(sp_data*, sp_buthp*, double*, double*)

cpdef list split(SoundBuffer snd, double interval=*, object drift=*, double driftwidth=*)
cpdef list customsplit(SoundBuffer snd, list freqs)

cpdef SoundBuffer spread(SoundBuffer snd, double amount=*)
cpdef SoundBuffer smear(SoundBuffer snd, double amount=*)
