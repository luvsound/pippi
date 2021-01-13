#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables
from pippi cimport interpolation
from pippi.rand cimport rand

cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2
cdef inline double MIN_PULSEWIDTH = 0.001

cdef class Pulsar:
    """ Pulsar synthesis
    """
    def __cinit__(
            self, 
            object wavetable=None, 
            object window=None, 

            object freq=440.0, 
            object pulsewidth=1.0,
            object amp=1.0, 
            double phase=0, 

            object freq_interpolator=None,

            tuple burst=None,
            object mask=0.0,

            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.freq = wavetables.to_wavetable(freq)
        self.amp = wavetables.to_window(amp)
        self.mask = wavetables.to_window(mask)

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        self.freq_interpolator = interpolation.get_point_interpolator(freq_interpolator)

        if burst is not None:
            self.burst_length = burst[0] + burst[1]
            self.burst = np.array(([1]*burst[0]) + ([0]*burst[1]), dtype='long')
        else:
            self.burst_length = 1
            self.burst = np.array([1], dtype='long')

        self.wt_phase = phase
        self.win_phase = phase
        self.freq_phase = phase
        self.pw_phase = phase
        self.amp_phase = phase
        self.burst_phase = phase
        self.mask_phase = phase

        self.channels = channels
        self.samplerate = samplerate

        self.pulsewidth = wavetables.to_wavetable(pulsewidth)
        self.wavetable = wavetables.to_wavetable(wavetable)
        self.window = wavetables.to_window(window)

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef object _play(self, int length):
        cdef int i = 0
        cdef long burst = 1
        cdef long mask = 1
        cdef double sample, pulsewidth, freq, mask_prob

        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        cdef double isamplerate = 1.0 / self.samplerate
        cdef double ilength = 1.0 / length

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)
        cdef int pw_boundry = max(len(self.pulsewidth)-1, 1)
        cdef int mask_boundry = max(len(self.mask)-1, 1)
        cdef int burst_boundry = max(len(self.burst)-1, 1)

        cdef int wt_length = len(self.wavetable)
        cdef int wt_boundry = max(wt_length-1, 1)
        cdef int win_length = len(self.window)
        cdef int win_boundry = max(win_length-1, 1)
        cdef int wt_boundry_p = wt_boundry
        cdef int win_boundry_p = win_boundry

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double amp_phase_inc = ilength * amp_boundry
        cdef double pw_phase_inc = ilength * pw_boundry
        cdef double mask_phase_inc = ilength * mask_boundry

        for i in range(length):
            freq = self.freq_interpolator(self.freq, self.freq_phase)
            pulsewidth = max(interpolation._linear_point(self.pulsewidth, self.pw_phase), MIN_PULSEWIDTH)
            amp = interpolation._linear_point(self.amp, self.amp_phase)
            mask_prob = interpolation._linear_point(self.mask, self.mask_phase)
            burst = self.burst[<int>self.burst_phase]

            ipulsewidth = 1.0/pulsewidth
            wt_boundry_p = <int>max((ipulsewidth * wt_length)-1, 1)
            win_boundry_p = <int>max((ipulsewidth * win_length)-1, 1)

            sample = interpolation._linear_point_pw(self.wavetable, self.wt_phase, pulsewidth)
            sample *= interpolation._linear_point_pw(self.window, self.win_phase, pulsewidth)
            sample *= amp * burst * mask

            self.freq_phase += freq_phase_inc
            self.amp_phase += amp_phase_inc
            self.pw_phase += pw_phase_inc
            self.mask_phase += mask_phase_inc
            self.wt_phase += isamplerate * wt_boundry_p * freq
            self.win_phase += isamplerate * win_boundry_p * freq

            if self.wt_phase >= wt_boundry_p:
                self.burst_phase += 1
                if rand(0,1) < mask_prob:
                    mask = 0
                else:
                    mask = 1

            while self.wt_phase >= wt_boundry_p:
                self.wt_phase -= wt_boundry_p

            while self.win_phase >= win_boundry_p:
                self.win_phase -= win_boundry_p

            while self.pw_phase >= pw_boundry:
                self.pw_phase -= pw_boundry

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            while self.mask_phase >= mask_boundry:
                self.mask_phase -= mask_boundry

            while self.burst_phase >= burst_boundry:
                self.burst_phase -= burst_boundry

            for channel in range(self.channels):
                out[i][channel] = sample

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

