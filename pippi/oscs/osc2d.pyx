#cython: language_level=3

import numbers
import numpy as np
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables
from pippi cimport interpolation

cimport cython
from cpython.array cimport array, clone

cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2
cdef inline double MIN_PULSEWIDTH = 0.0001


cdef class Osc2d:
    """ 1d or 2d wavetable osc
    """
    def __cinit__(
            self, 
              list stack=None,
            object freq=440, 
            object amp=1, 
            double pulsewidth=1,
            double phase=0, 

            object freq_interpolator=None,

            object window=None, 
            double win_phase=0, 

            object mod=None, 
            double mod_freq=0.2, 
            double mod_range=0, 
            double mod_phase=0, 

            object lfo=None, 
            double lfo_freq=0.2, 

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.freq = wavetables.to_wavetable(freq)
        self.amp = wavetables.to_window(amp)
        self.phase = phase

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        self.freq_interpolator = interpolation.get_point_interpolator(freq_interpolator)

        self.channels = channels
        self.samplerate = samplerate
        self.wtsize = wtsize

        self.pulsewidth = pulsewidth if pulsewidth >= MIN_PULSEWIDTH else MIN_PULSEWIDTH
        self.wavetables = wavetables.to_stack(stack, self.wtsize)

        self.window = wavetables.to_wavetable(window, self.wtsize)

        self.win_phase = win_phase
        self.mod_range = mod_range
        self.mod_phase = mod_phase
        self.mod_freq = mod_freq
        self.mod = wavetables.to_wavetable(mod, self.wtsize)

        self.lfo_freq = lfo_freq

        if lfo is None:
            self.lfo = wavetables._wavetable(wavetables.RSAW, self.wtsize)

    def play(self, 
             length, 
             freq=None, 
             amp=None, 
             pulsewidth=-1,
             mod_freq=-1,
             mod_range=-1,
        ):

        framelength = <int>(length * self.samplerate)

        if freq is not None:
            self.freq = wavetables.to_wavetable(freq)

        if amp is not None:
            self.amp = wavetables.to_window(amp)

        if pulsewidth > 0:
            self.pulsewidth = pulsewidth 

        if mod_freq > 0:
            self.mod_freq = mod_freq 

        if mod_range >= 0:
            self.mod_range = mod_range 

        return self._play2d(framelength)

    cdef object _play2d(self, int length):
        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')
        cdef double[:,:] stack = np.column_stack(self.wavetables)
        cdef int stack_depth = len(self.wavetables)
        cdef double isamplerate = (1.0 / self.samplerate)
        cdef double ilength = 1.0 / length
        cdef double wt_lfo_phase_inc = len(self.lfo) * (1.0 / length)

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double amp_phase_inc = ilength * amp_boundry

        cdef double phase_inc, wt_phase_inc, freq, amp
        cdef double wt_lfo_phase, wt_lfo_frac, wt_lfo_y0, wt_lfo_y1, wt_lfo_pos
        cdef double stack_frac, stack_phase
        cdef double phase, frac, y0, y1, val
        cdef double wt_mod_val = 1
        cdef double wt_mod_phase = 0
        cdef double wt_mod_frac = 0
        cdef double wt_mod_next = 0

        cdef int i, wt_lfo_x, stack_x, channel, wt_mod_i
        cdef int wt_mod_length = 1 if self.mod is None else len(self.mod)
        cdef int wt_mod_boundry = wt_mod_length - 1
        cdef double wt_phase = 0
        cdef double wt_mod_phase_inc = self.mod_freq * (1.0 / length) * wt_mod_length

        for i in range(length):
            freq = self.freq_interpolator(self.freq, self.freq_phase)
            amp = interpolation._linear_point(self.amp, self.amp_phase)

            phase_inc = freq * self.wtsize * isamplerate
            wt_phase_inc = freq * self.wtsize * isamplerate

            if self.mod is not None:
                wt_mod_i = <int>self.mod_phase % wt_mod_length
                if wt_mod_i < wt_mod_boundry:
                    wt_mod_next = self.mod[wt_mod_i + 1]
                else:
                    wt_mod_next = self.mod[0]

                wt_mod_frac = self.mod_phase - <int>self.mod_phase
                wt_mod_val = self.mod[wt_mod_i]
                wt_mod_val = (1.0 - wt_mod_frac) * wt_mod_val + (wt_mod_frac * wt_mod_next)
                wt_mod_val = 1.0 + (wt_mod_val * self.mod_range)
                self.mod_phase += wt_mod_phase_inc

            # Calculate stack LFO position
            wt_lfo_phase = i * wt_lfo_phase_inc
            wt_lfo_x = <int>wt_lfo_phase
            wt_lfo_frac = wt_lfo_phase - wt_lfo_x
            wt_lfo_y0 = self.lfo[wt_lfo_x % len(self.lfo)]
            wt_lfo_y1 = self.lfo[(wt_lfo_x + 1) % len(self.lfo)]
            wt_lfo_pos = (1.0 - wt_lfo_frac) * wt_lfo_y0 + (wt_lfo_frac * wt_lfo_y1)

            # Calculate wavetable value based on LFO position
            stack_phase = wt_lfo_pos * stack_depth
            stack_x = <int>stack_phase
            wt_phase += (wt_phase_inc * wt_mod_val)
            wt_x = <int>wt_phase
            stack_frac = stack_phase - stack_x
            y0 = self.wavetables[stack_x % stack_depth][wt_x % self.wtsize]
            y1 = self.wavetables[(stack_x + 1) % stack_depth][wt_x % self.wtsize]
            val = (1.0 - stack_frac) * y0 + (stack_frac * y1)

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            for channel in range(self.channels):
                out[i][channel] = val * amp

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)


