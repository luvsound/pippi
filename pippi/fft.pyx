#cython: language_level=3

from libc.stdlib cimport malloc, free
from libc cimport math

import numpy as np
cimport numpy as np

from pippi.interpolation cimport _linear_pos
from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport to_window, Wavetable
from pippi.defaults cimport DEFAULT_SAMPLERATE

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

cpdef tuple to_xy(SoundBuffer mag, SoundBuffer arg):
    cdef int channels = mag.channels
    cdef size_t length = len(mag)
    cdef double[:,:] _mag = mag.frames
    cdef double[:,:] _arg = arg.frames
    cdef double[:,:] real = np.zeros((length, channels), dtype='d')
    cdef double[:,:] imag = np.zeros((length, channels), dtype='d')

    cdef size_t i = 0
    cdef size_t c = 0

    for c in range(channels):
        for i in range(length):
            real[i,c] = _mag[i,c] * math.cos(_arg[i,c])
            imag[i,c] = _mag[i,c] * math.sin(_arg[i,c])

    return (
        SoundBuffer(real, channels=channels, samplerate=mag.samplerate), 
        SoundBuffer(imag, channels=channels, samplerate=mag.samplerate)
    )

cpdef tuple to_polar(SoundBuffer real, SoundBuffer imag):
    cdef int channels = real.channels
    cdef size_t length = len(real)
    cdef double[:,:] mag = np.zeros((length, real.channels), dtype='d')
    cdef double[:,:] arg = np.zeros((length, real.channels), dtype='d')
    cdef double[:,:] _real = real.frames
    cdef double[:,:] _imag = imag.frames

    cdef size_t i = 0
    cdef size_t c = 0

    for c in range(channels):
        for i in range(length):
            # Calculate the magnitude of the complex number
            mag[i,c] = math.sqrt((_real[i,c] * _real[i,c]) + (_imag[i,c] * _imag[i,c]))

            # Calculate the argument / angle of the complex vector
            if _real[i,c] == 0:
                arg[i,c] = 0
            else:
                arg[i,c] = math.atan(_imag[i,c] / _real[i,c])

    return (
        SoundBuffer(mag, channels=channels, samplerate=real.samplerate), 
        SoundBuffer(arg, channels=channels, samplerate=real.samplerate)
    )

cpdef tuple transform(SoundBuffer snd):
    cdef int channels = snd.channels
    cdef size_t length = len(snd)
    cdef double[:,:] src = snd.frames
    cdef double[:,:] rout = np.zeros((length, channels), dtype='d')
    cdef double[:,:] iout = np.zeros((length, channels), dtype='d')

    cdef size_t i = 0
    cdef size_t c = 0
    cdef double pos = 0

    cdef double* _real = <double*>malloc(sizeof(double) * length)
    cdef double* _imag = <double*>malloc(sizeof(double) * length)

    for c in range(channels):
        for i in range(length):
            _real[i] = src[i,c]
            _imag[i] = 0

        Fft_transform(_real, _imag, length)

        for i in range(length):
            rout[i,c] = _real[i]
            iout[i,c] = _imag[i]

    free(_real)
    free(_imag)

    return (
        SoundBuffer(rout, channels=channels, samplerate=snd.samplerate), 
        SoundBuffer(iout, channels=channels, samplerate=snd.samplerate)
    )

cpdef SoundBuffer itransform(SoundBuffer real, SoundBuffer imag):
    assert real.channels == imag.channels
    assert len(real) == len(imag)

    cdef int channels = real.channels
    cdef size_t length = len(real)

    cdef double[:,:] out = np.zeros((length, channels), dtype='d')

    cdef size_t i = 0
    cdef size_t c = 0
    cdef double pos = 0

    cdef double* _real = <double*>malloc(sizeof(double) * length)
    cdef double* _imag = <double*>malloc(sizeof(double) * length)

    for c in range(channels):
        for i in range(length):
            _real[i] = real.frames[i,c]
            _imag[i] = imag.frames[i,c]

        Fft_inverseTransform(_real, _imag, length)

        for i in range(length):
            out[i,c] = _real[i]

    free(_real)
    free(_imag)

    return SoundBuffer(out, channels=channels, samplerate=real.samplerate)

def passthru(pos, real, imag):
    return real, imag

cpdef SoundBuffer process(SoundBuffer snd, object blocksize=0.01, object length=None, object callback=None, object window=None):
    cdef double olength = snd.dur
    cdef double _length = <double>(length or olength)
    cdef double samplerate = <double>snd.samplerate
    cdef long framelength = <long>(_length * samplerate)
    cdef SoundBuffer out = SoundBuffer(length=_length)
    cdef double[:] _blocksize = to_window(blocksize)

    cdef SoundBuffer rblock
    cdef SoundBuffer iblock
    cdef SoundBuffer block

    cdef double pos = 0
    cdef double elapsed = 0
    cdef double bs = _blocksize[0]
    cdef double taper = (1/samplerate) * 20

    if callback is None:
        callback = passthru

    cdef double[:] win = to_window(window or 'sine')

    while elapsed <= _length:
        pos = elapsed / _length
        bs = _linear_pos(_blocksize, pos)
        rblock, iblock = transform(snd.cut(pos*olength, bs).env(win))
        rblock, iblock = callback(pos, rblock, iblock)
        block = itransform(rblock, iblock).taper(taper)
        out.dub(block, elapsed)
        elapsed += bs/2

    return out
