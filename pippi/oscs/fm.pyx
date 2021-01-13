#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables
from pippi cimport interpolation

cimport cython
from libc cimport math

cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2
cdef inline double MIN_PULSEWIDTH = 0.0001

cdef class FM:
    """ Basic FM synth
    """
    def __cinit__(
            self, 
            object carrier=None, 
            object modulator=None, 
            object freq=440.0, 
            object ratio=1.0, 
            object index=None, 
            object amp=1.0, 
            double phase=0, 

            object freq_interpolator=None,

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        if carrier is None:
            carrier = 'sine'

        if modulator is None:
            modulator = 'sine'

        if index is None:
            index = 'hannout'

        self.freq = wavetables.to_window(freq, self.wtsize)
        self.ratio = wavetables.to_window(ratio, self.wtsize)
        self.index = wavetables.to_window(index, self.wtsize)
        self.amp = wavetables.to_window(amp, self.wtsize)

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        self.freq_interpolator = interpolation.get_point_interpolator(freq_interpolator)

        self.cwt_phase = phase
        self.mwt_phase = phase
        self.freq_phase = 0
        self.ratio_phase = 0
        self.index_phase = 0
        self.amp_phase = 0

        self.channels = channels
        self.samplerate = samplerate
        self.wtsize = wtsize

        self.carrier = wavetables.to_wavetable(carrier, self.wtsize)
        self.modulator = wavetables.to_wavetable(modulator, self.wtsize)

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef object _play(self, int length):
        cdef int i = 0
        cdef double sample, freq, ratio, index, amp, mod, mfreq, cfreq
        cdef double ilength = 1.0 / length
        cdef double isamplerate = 1.0 / self.samplerate

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int ratio_boundry = max(len(self.ratio)-1, 1)
        cdef int index_boundry = max(len(self.index)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)
        cdef int cwt_boundry = max(len(self.carrier)-1, 1)
        cdef int mwt_boundry = max(len(self.modulator)-1, 1)

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double ratio_phase_inc = ilength * ratio_boundry
        cdef double index_phase_inc = ilength * index_boundry
        cdef double amp_phase_inc = ilength * amp_boundry

        cdef double cwt_phase_inc = isamplerate * self.wtsize
        cdef double mwt_phase_inc = isamplerate * self.wtsize

        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        for i in range(length):
            freq = self.freq_interpolator(self.freq, self.freq_phase)
            ratio = interpolation._linear_point(self.ratio, self.ratio_phase)
            index = interpolation._linear_point(self.index, self.index_phase)

            amp = interpolation._linear_point(self.amp, self.amp_phase)
            mamp = freq * index * ratio

            mod = interpolation._linear_point(self.modulator, self.mwt_phase) * mamp
            sample = interpolation._linear_point(self.carrier, self.cwt_phase) * amp

            cfreq = freq + mod
            mfreq = freq * ratio

            self.freq_phase += freq_phase_inc
            self.ratio_phase += ratio_phase_inc
            self.index_phase += index_phase_inc
            self.amp_phase += amp_phase_inc

            self.cwt_phase += cfreq * cwt_phase_inc
            self.mwt_phase += mfreq * mwt_phase_inc

            if self.cwt_phase < 0:
                self.cwt_phase += cwt_boundry
            elif self.cwt_phase >= cwt_boundry:
                self.cwt_phase -= cwt_boundry

            while self.mwt_phase >= mwt_boundry:
                self.mwt_phase -= mwt_boundry

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            while self.ratio_phase >= ratio_boundry:
                self.ratio_phase -= ratio_boundry

            while self.index_phase >= index_boundry:
                self.index_phase -= index_boundry

            for channel in range(self.channels):
                out[i][channel] = sample

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

