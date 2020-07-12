#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

cdef extern from "stdbool.h":
    ctypedef bint bool

cdef extern from "fft.h":
    bool Fft_transform(double real[], double imag[], size_t n)
    bool Fft_inverseTransform(double real[], double imag[], size_t n)
    bool Fft_transformRadix2(double real[], double imag[], size_t n)
    bool Fft_transformBluestein(double real[], double imag[], size_t n)
    bool Fft_convolveReal(const double x[], const double y[], double out[], size_t n)
    bool Fft_convolveComplex(const double xreal[], const double ximag[], const double yreal[], const double yimag[], double outreal[], double outimag[], size_t n)

cdef double[:] _conv(double[:] x, double[:] y)
cpdef double[:,:] conv(double[:,:] src, double[:,:] impulse)

cpdef tuple to_xy(SoundBuffer mag, SoundBuffer arg)
cpdef tuple to_polar(SoundBuffer real, SoundBuffer imag)
cpdef tuple transform(SoundBuffer snd)
cpdef SoundBuffer itransform(SoundBuffer real, SoundBuffer imag)
cpdef SoundBuffer process(SoundBuffer snd, object blocksize=*, object length=*, object callback=*, object window=*)
