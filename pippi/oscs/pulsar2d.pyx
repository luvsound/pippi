#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables as wts
from pippi cimport interpolation
from pippi.rand cimport rand

from pippi.defaults cimport DEFAULT_SAMPLERATE, DEFAULT_WTSIZE, DEFAULT_CHANNELS, MIN_PULSEWIDTH


cdef class Pulsar2d:
    """ Pulsar synthesis with a 2d wavetable & window stack
    """
    def __cinit__(
            self, 
            object wavetables=None, 
            object windows=None, 

            object freq=440.0, 
            object pulsewidth=1,
            object amp=1.0, 
            double phase=0, 

            object freq_interpolator=None,

            object wt_mod=None, 
            object win_mod=None, 

            object burst=None,
            object mask=0.0,

            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        if wt_mod is None:
            wt_mod = 'saw'

        if win_mod is None:
            win_mod = 'saw'

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        self.freq = wts.to_wavetable(freq)
        self.amp = wts.to_window(amp)
        self.wt_mod = wts.to_window(wt_mod)
        self.win_mod = wts.to_window(win_mod)
        self.mask = wts.to_window(mask)

        self.freq_interpolator = interpolation.get_point_interpolator(freq_interpolator)

        if burst is not None:
            self.burst_length = len(burst)
            self.burst = np.array(burst, dtype='long')
        else:
            self.burst_length = 1
            self.burst = np.array([1], dtype='long')

        self.wt_phase = phase
        self.win_phase = 0
        self.freq_phase = 0
        self.pw_phase = 0
        self.amp_phase = 0
        self.burst_phase = 0
        self.mask_phase = 0

        self.channels = channels
        self.samplerate = samplerate

        self.pulsewidth = wts.to_wavetable(pulsewidth)

        cdef double[:] wt
        cdef double[:] win
        cdef double val
        cdef int i
        cdef int j

        if wavetables is None:
            wavetables = ['sine']

        self.wt_length = DEFAULT_WTSIZE
        for wavetable in wavetables:
            if isinstance(wavetable, str):
                # We haven't parsed the wavetable stack yet, so 
                # getting the len of `wavetable` might not make sense -
                # eg when it is the string "sine" or something. So 
                # we'll assume any built-in wavetable names will be 
                # at the default wavetable size.
                self.wt_length = max(DEFAULT_WTSIZE, self.wt_length)
                continue

            self.wt_length = max(len(wavetable), self.wt_length)

        self.wt_count = len(wavetables)
        self.wavetables = np.zeros((self.wt_count, self.wt_length), dtype='d')

        for i, wavetable in enumerate(wavetables):
            wt = wts.to_wavetable(wavetable, self.wt_length)
            if len(wt) < self.wt_length:
                wt = interpolation._linear(wt, self.wt_length)

            for j, val in enumerate(wt):
                self.wavetables[i][j] = val                

        if windows is None:
            windows = ['sine']

        self.win_length = DEFAULT_WTSIZE
        for window in windows:
            if isinstance(wavetable, str):
                # Same dumb workaround for built-in wavetable string literals
                self.wt_length = max(DEFAULT_WTSIZE, self.wt_length)
                continue

            self.win_length = max(len(window), self.win_length)

        self.win_count = len(windows)
        self.windows = np.zeros((self.win_count, self.win_length), dtype='d')

        for i, window in enumerate(windows):
            win = wts.to_window(window, self.win_length)
            if len(win) < self.win_length:
                win = interpolation._linear(win, self.win_length)

            for j, val in enumerate(win):
                try:
                    self.windows[i][j] = val                
                except IndexError as e:
                    break


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
        cdef int wt_mod_boundry = max(len(self.wt_mod)-1, 1)
        cdef int win_mod_boundry = max(len(self.win_mod)-1, 1)
        cdef int mask_boundry = max(len(self.mask)-1, 1)
        cdef int burst_boundry = max(len(self.burst)-1, 1)

        cdef int wt_boundry = max(self.wt_length-1, 1)
        cdef int win_boundry = max(self.win_length-1, 1)
        cdef int wt_boundry_p = wt_boundry
        cdef int win_boundry_p = win_boundry

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double amp_phase_inc = ilength * amp_boundry
        cdef double pw_phase_inc = ilength * pw_boundry
        cdef double wt_mod_phase_inc = ilength * wt_mod_boundry
        cdef double win_mod_phase_inc = ilength * win_mod_boundry
        cdef double mask_phase_inc = ilength * mask_boundry

        cdef int wi = 0
        cdef double wi_phase = 0
        cdef double wi_frac = 0
        cdef double wt_out_a = 0
        cdef double wt_out_b = 0
        cdef double win_out_a = 0
        cdef double win_out_b = 0

        for i in range(length):
            freq = self.freq_interpolator(self.freq, self.freq_phase)
            mask_prob = interpolation._linear_point(self.mask, self.mask_phase)
            burst = self.burst[<int>self.burst_phase]

            pulsewidth = max(interpolation._linear_point(self.pulsewidth, self.pw_phase), MIN_PULSEWIDTH)
            ipulsewidth = 1.0/pulsewidth
            wt_boundry_p = <int>max((ipulsewidth * self.wt_length)-1, 1)
            win_boundry_p = <int>max((ipulsewidth * self.win_length)-1, 1)

            if burst > 0 and mask > 0:
                amp = interpolation._linear_point(self.amp, self.amp_phase)
                self.wt_pos = interpolation._linear_point(self.wt_mod, self.wt_mod_phase)
                self.win_pos = interpolation._linear_point(self.win_mod, self.win_mod_phase)

                if self.wt_count == 1:
                    sample = interpolation._linear_point_pw(self.wavetables[0], self.wt_phase, pulsewidth) 
                else:
                    wi_phase = self.wt_pos * (self.wt_count-2)
                    wi = <int>wi_phase
                    wi_frac = wi_phase - wi
                    wt_out_a = interpolation._linear_point_pw(self.wavetables[wi], self.wt_phase, pulsewidth)
                    wt_out_b = interpolation._linear_point_pw(self.wavetables[wi+1], self.wt_phase, pulsewidth)
                    sample = (1.0 - wi_frac) * wt_out_a + (wi_frac * wt_out_b)

                if self.win_count == 1:
                    sample *= interpolation._linear_point_pw(self.windows[0], self.win_phase, pulsewidth)
                else:
                    wi_phase = self.win_pos * (self.win_count-2)
                    wi = <int>wi_phase
                    wi_frac = wi_phase - wi
                    win_out_a = interpolation._linear_point_pw(self.windows[wi], self.win_phase, pulsewidth)
                    win_out_b = interpolation._linear_point_pw(self.windows[wi+1], self.win_phase, pulsewidth)
                    sample *= (1.0 - wi_frac) * win_out_a + (wi_frac * win_out_b)

                sample *= amp
            else:
                sample = 0

            self.freq_phase += freq_phase_inc
            self.amp_phase += amp_phase_inc
            self.pw_phase += pw_phase_inc
            self.mask_phase += mask_phase_inc
            self.wt_mod_phase += wt_mod_phase_inc
            self.win_mod_phase += win_mod_phase_inc
            self.wt_phase += isamplerate * wt_boundry_p * freq
            self.win_phase += isamplerate * win_boundry_p * freq

            if self.wt_phase >= wt_boundry_p:
                self.burst_phase += 1
                if rand(0,1) < mask_prob:
                    mask = 0
                else:
                    mask = 1

            if self.wt_phase < 0:
                self.wt_phase += wt_boundry_p
            elif self.wt_phase >= wt_boundry_p:
                self.wt_phase -= wt_boundry_p

            while self.win_phase >= win_boundry_p:
                self.win_phase -= win_boundry_p

            while self.wt_mod_phase >= wt_mod_boundry:
                self.wt_mod_phase -= wt_mod_boundry

            while self.win_mod_phase >= win_mod_boundry:
                self.win_mod_phase -= win_mod_boundry

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

