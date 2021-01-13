#cython: language_level=3

from libc cimport math

from pippi cimport wavetables, interpolation
from pippi.defaults cimport DEFAULT_CHANNELS, DEFAULT_SAMPLERATE, PI
from pippi.soundbuffer cimport SoundBuffer

import numpy as np


cdef class Tukey:
    def __cinit__(
            Tukey self, 
            object freq=440.0, 
            object shape=0.5,
            object amp=1.0, 
            double phase=0,            
            object freq_interpolator=None,

            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.phase = phase        
        self.channels = channels
        self.samplerate = samplerate

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        if shape is None:
            shape = 'sine'

        self.amp = wavetables.to_window(amp)
        self.shape = wavetables.to_window(shape)
        self.freq = wavetables.to_window(freq)
        self.freq_interpolator = interpolation.get_pos_interpolator(freq_interpolator)

    cpdef SoundBuffer play(Tukey self, double length=1):
        cdef int c=0, i=0
        cdef double r=0, pos=0, sample=0, a=0, x=0, amp=1

        cdef long _length = <long>(length * self.samplerate)
        cdef double[:,:] out = np.zeros((_length, self.channels))
        cdef int direction = 1
        cdef double PI2 = PI*2

        while i < _length:
            pos = <double>i / <double>_length
            amp = interpolation._linear_pos(self.amp, pos)
            r = interpolation._linear_pos(self.shape, pos)
            r = max(r, 0.00001)

            f = self.freq_interpolator(self.freq, pos)

            a = PI2 / r

            # Implementation based on https://www.mathworks.com/help/signal/ref/tukeywin.html
            if self.phase <= r / 2:
                sample = 0.5 * (1 + math.cos(a * (self.phase - r / 2)))

            elif self.phase < 1 - (r/2):
                sample = 1

            else:
                sample = 0.5 * (1 + math.cos(a * (self.phase - 1 + r / 2)))

            sample *= direction

            for c in range(self.channels):
                out[i,c] = sample * amp

            self.phase += (1.0/self.samplerate) * f * 2

            if self.phase > 1:
                direction *= -1
            while self.phase >= 1:
                self.phase -= 1

            i += 1

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

