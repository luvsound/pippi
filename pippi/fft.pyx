#cython: language_level=3

from libc.stdlib cimport malloc, free

import numpy as np
cimport numpy as np

from pippi.soundbuffer cimport SoundBuffer

np.import_array()

cdef double[:] _conv(double[:] x, double[:] y):
    cdef size_t i = 0
    cdef size_t x_length = len(x)
    cdef size_t y_length = len(y)
    cdef size_t length = x_length + y_length + 1

    cdef double* _x = <double*>malloc(sizeof(double) * length)
    cdef double* _y = <double*>malloc(sizeof(double) * length)
    cdef double* _out = <double*>malloc(sizeof(double) * length)

    for i in range(length):
        if i < x_length:
            _x[i] = x[i]
        else:
            _x[i] = 0

        if i < y_length:
            _y[i] = y[i]
        else:
            _y[i] = 0

    Fft_convolveReal(_x, _y, _out, length)

    cdef double[:] out = np.zeros(length, dtype='d')

    for i in range(length):
        out[i] = _out[i]

    free(_x)
    free(_y)
    free(_out)

    return out

cpdef double[:,:] conv(double[:,:] src, double[:,:] impulse):
    cdef int channels = src.shape[1]
    cdef size_t length = len(src) + len(impulse) + 1
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')

    for c in range(channels):
        out[:,c] = _conv(src[:,c], impulse[:,c])

    return out


