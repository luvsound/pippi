#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables
from pippi cimport interpolation

cimport cython
cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2
cdef inline double MIN_PULSEWIDTH = 0.0001

cdef class Alias:
    """ Single-sample aliasing pulse train osc 
    """
    def __cinit__(
            self, 
            object freq=440.0, 
            object amp=1.0, 
            double phase=0, 

            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.freq = wavetables.to_wavetable(freq)
        self.amp = wavetables.to_window(amp)

        self.freq_phase = phase
        self.amp_phase = phase
        self.pulse_phase = <int>phase

        self.channels = channels
        self.samplerate = samplerate

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef object _play(self, int length):
        cdef int i = 0
        cdef double sample, freq, amp
        cdef double ilength = 1.0 / length
        cdef int freq_width

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double amp_phase_inc = ilength * amp_boundry

        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        for i in range(length):
            freq = interpolation._linear_point(self.freq, self.freq_phase)
            amp = interpolation._linear_point(self.amp, self.amp_phase)

            if self.pulse_phase == 0:
                sample = amp
            else:
                sample = 0

            freq_width = <int>(self.samplerate / freq)

            self.freq_phase += freq_phase_inc
            self.amp_phase += amp_phase_inc
            self.pulse_phase += 1

            while self.pulse_phase >= freq_width:
                self.pulse_phase -= freq_width

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            for channel in range(self.channels):
                out[i][channel] = sample

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

