#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables
from pippi cimport interpolation
from pippi.fx cimport _fold_point

cimport cython
cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2

cdef class Fold:
    """ Saturating feedback wavefolder osc
    """
    def __cinit__(
            self, 
            object wavetable=None, 
            object freq=440.0, 
            object amp=1.0,
            double phase=0, 

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.freq = wavetables.to_wavetable(freq, self.wtsize)
        self.amp = wavetables.to_window(amp, self.wtsize)

        self.wt_phase = phase
        self.freq_phase = 0
        self.amp_phase = 0

        self.channels = channels
        self.samplerate = samplerate
        self.wtsize = wtsize

        self.wavetable = wavetables.to_wavetable(wavetable, self.wtsize)

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef SoundBuffer _play(self, int length):
        cdef int i = 0
        cdef double sample, freq, amp
        cdef double ilength = 1.0 / length

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)
        cdef int wt_boundry = max(len(self.wavetable)-1, 1)

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double amp_phase_inc = ilength * amp_boundry

        cdef double wt_phase_inc = (1.0 / self.samplerate) * self.wtsize
        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        cdef double last = 0

        for i in range(length):
            freq = interpolation._linear_point(self.freq, self.freq_phase)
            amp = interpolation._linear_point(self.amp, self.amp_phase)
            sample = interpolation._linear_point(self.wavetable, self.wt_phase) * amp
            sample = _fold_point(sample, last, <double>self.samplerate)
            last = sample

            self.freq_phase += freq_phase_inc
            self.amp_phase += amp_phase_inc
            self.wt_phase += freq * wt_phase_inc

            if self.wt_phase < 0:
                self.wt_phase += wt_boundry
            elif self.wt_phase >= wt_boundry:
                self.wt_phase -= wt_boundry

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            for channel in range(self.channels):
                out[i][channel] = sample

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

