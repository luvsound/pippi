#cython: language_level=3

from libc cimport math

from pippi cimport wavetables, interpolation
from pippi.defaults cimport DEFAULT_CHANNELS, DEFAULT_SAMPLERATE
from pippi.soundbuffer cimport SoundBuffer

import numpy as np


cdef class Tukey:
    def __cinit__(
            Tukey self, 
            double phase=0,            
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.phase = phase        
        self.channels = channels
        self.samplerate = samplerate

    cpdef SoundBuffer play(Tukey self, double length=1, object freq=440.0, object shape=0.5):
        cdef int c=0, i=0
        cdef double r=0, pos=0, sample=0, a=0, x=0

        cdef double[:] _shape = wavetables.to_window(shape)
        cdef double[:] _freq = wavetables.to_window(freq)

        cdef long _length = <long>(length * self.samplerate)
        cdef double[:,:] out = np.zeros((_length, self.channels))
        cdef int direction = 1

        while i < _length:
            pos = <double>i / <double>_length
            r = interpolation._linear_pos(_shape, pos)
            r = max(r, 0.00001)

            f = interpolation._linear_pos(_freq, pos)

            a = (2*math.pi) / r

            # Implementation based on https://www.mathworks.com/help/signal/ref/tukeywin.html
            if self.phase <= r / 2:
                sample = 0.5 * (1 + math.cos(a * (self.phase - r / 2)))

            elif self.phase < 1 - (r/2):
                sample = 1

            else:
                sample = 0.5 * (1 + math.cos(a * (self.phase - 1 + r / 2)))

            sample *= direction

            for c in range(self.channels):
                out[i,c] = sample 

            self.phase += (1.0/self.samplerate) * f * 2

            if self.phase > 1:
                direction *= -1
            while self.phase >= 1:
                self.phase -= 1

            i += 1

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

