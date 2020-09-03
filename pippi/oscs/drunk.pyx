#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport rand
from pippi cimport wavetables
from pippi cimport interpolation

cimport cython
cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2
cdef inline double MIN_PULSEWIDTH = 0.0001

cdef class Drunk:
    """ N-point wavetable drunk walk morph
    """
    def __cinit__(
            self, 
            int points=10,
            object freq=440.0, 
            object width=0.01, 
            object amp=1.0, 
            double phase=0, 

            object freq_interpolator=None,

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.wtsize = wtsize
        self.numpoints = points
        self.freq = wavetables.to_wavetable(freq)
        self.width = wavetables.to_wavetable(width)
        self.amp = wavetables.to_window(amp)

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        self.freq_interpolator = interpolation.get_point_interpolator(freq_interpolator)

        self.wt_phase = phase
        self.freq_phase = 0
        self.width_phase = 0
        self.amp_phase = 0

        self.channels = channels
        self.samplerate = samplerate

        self.wavetable = np.array([0] + [ rand.rand(-1, 1) for _ in range(points) ] + [0], dtype='d')

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef object _play(self, int length):
        cdef int i = 0
        cdef double sample, freq, amp, width
        cdef double ilength = 1.0 / length

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int width_boundry = max(len(self.width)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)
        cdef int wt_boundry = max(len(self.wavetable)-1, 1)

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double width_phase_inc = ilength * width_boundry
        cdef double amp_phase_inc = ilength * amp_boundry

        cdef double wt_phase_inc = (1.0 / self.samplerate) * self.numpoints
        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        for i in range(length):
            freq = self.freq_interpolator(self.freq, self.freq_phase)
            width = interpolation._linear_point(self.width, self.width_phase)
            amp = interpolation._linear_point(self.amp, self.amp_phase)
            sample = interpolation._hermite_point(self.wavetable, self.wt_phase) * amp

            self.freq_phase += freq_phase_inc
            self.width_phase += width_phase_inc
            self.amp_phase += amp_phase_inc
            self.wt_phase += freq * wt_phase_inc

            if self.wt_phase >= wt_boundry:
                self.wavetable = wavetables._drink(self.wavetable, width, -1, 1)

            while self.wt_phase >= wt_boundry:
                self.wt_phase -= wt_boundry

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            while self.width_phase >= width_boundry:
                self.width_phase -= width_boundry

            for channel in range(self.channels):
                out[i][channel] = sample

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

