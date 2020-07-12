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

cdef class DSS:
    """ 1d or 2d wavetable osc
    """
    def __cinit__(
            self, 
            object wavetable=None, 
            double freq=440, 
            double amp=1, 
            double pulsewidth=1,
            double phase=0, 

            object window=None, 
            double win_phase=0, 

            object mod=None, 
            double mod_freq=0.2, 
            double mod_range=0, 
            double mod_phase=0, 

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.freq = freq
        self.amp = amp
        self.phase = phase

        self.channels = channels
        self.samplerate = samplerate
        self.wtsize = wtsize

        self.pulsewidth = pulsewidth if pulsewidth >= MIN_PULSEWIDTH else MIN_PULSEWIDTH
        self.wavetable = wavetables.to_wavetable(wavetable, self.wtsize)
        self.window = wavetables.to_wavetable(window, self.wtsize)

        self.win_phase = win_phase
        self.mod_range = mod_range
        self.mod_phase = mod_phase
        self.mod_freq = mod_freq
        self.mod = wavetables.to_wavetable(mod, self.wtsize)

    def play(self, 
             length, 
             freq=-1, 
             amp=-1, 
             pulsewidth=-1,
             mod_freq=-1,
             mod_range=-1,
        ):

        framelength = <int>(length * self.samplerate)

        if freq > 0:
            self.freq = freq

        if amp >= 0:
            self.amp = amp 

        if pulsewidth > 0:
            self.pulsewidth = pulsewidth 

        if mod_freq > 0:
            self.mod_freq = mod_freq 

        if mod_range >= 0:
            self.mod_range = mod_range 

        return self._play(framelength)

    cdef object _play(self, int length):
        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        cdef int i = 0
        cdef int wtindex = 0
        cdef int modindex = 0
        cdef int wtlength = len(self.wavetable)
        cdef int wtboundry = wtlength - 1
        cdef int modlength = 1 if self.mod is None else len(self.mod)
        cdef int modboundry = modlength - 1
        cdef double val, val_mod, nextval, nextval_mod, frac, frac_mod
        cdef int silence_length

        cdef double[:] wavetable = self.wavetable
        cdef double[:] window

        cdef int j = 0

        if self.window is not None:
            window = interpolation._linear(self.window, wtlength)
            for j in range(wtlength):
                wavetable[j] *= window[j]

        if self.pulsewidth < 1:
            silence_length = <int>((wtlength / self.pulsewidth) - wtlength)
            wavetable = np.concatenate((wavetable, np.zeros(silence_length, dtype='d')))

        cdef double isamplerate = 1.0 / self.samplerate

        for i in range(length):
            wtindex = <int>self.phase % wtlength
            modindex = <int>self.mod_phase % modlength

            val = wavetable[wtindex]
            val_mod = 1

            if wtindex < wtboundry:
                nextval = wavetable[wtindex + 1]
            else:
                nextval = wavetable[0]

            if self.mod is not None:
                if modindex < modboundry:
                    nextval_mod = self.mod[modindex + 1]
                else:
                    nextval_mod = self.mod[0]

                frac_mod = self.mod_phase - <int>self.mod_phase
                val_mod = self.mod[modindex]
                val_mod = (1.0 - frac_mod) * val_mod + frac_mod * nextval_mod
                val_mod = 1.0 + (val_mod * self.mod_range)
                self.mod_phase += self.mod_freq * modlength * isamplerate

            frac = self.phase - <int>self.phase
            val = ((1.0 - frac) * val + frac * nextval) * self.amp
            self.phase += self.freq * val_mod * wtlength * isamplerate

            for channel in range(self.channels):
                out[i][channel] = val

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

