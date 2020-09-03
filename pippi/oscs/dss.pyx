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


cdef class DSS:
    """ Dynamic stochastic synthesis
    """
    def __cinit__(
            self, 
            int points=10,
            object freq=440.0, 
            object fbound=220.0,
            object fwidth=5, 
            object abound=0.3,
            object awidth=0.15, 
            object xwidth=0.001, 
            object ywidth=0.01, 
            object amp=1.0, 
            double phase=0, 

            object freq_interpolator=None,

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.wtsize = wtsize
        self.numpoints = points
        self.points = Breakpoint(points, wtsize)
        self.freq = wavetables.to_wavetable(freq)
        self.xwidth = wavetables.to_wavetable(xwidth)
        self.ywidth = wavetables.to_wavetable(ywidth)
        self.amp = wavetables.to_window(amp)

        self.fwidth = wavetables.to_wavetable(fwidth)
        self.awidth = wavetables.to_wavetable(awidth)
        self.fbound = wavetables.to_wavetable(fbound)
        self.abound = wavetables.to_wavetable(abound)

        if freq_interpolator is None:
            freq_interpolator = 'linear'

        self.freq_interpolator = interpolation.get_point_interpolator(freq_interpolator)

        self.wt_phase = phase
        self.freq_phase = 0
        self.xwidth_phase = 0 
        self.ywidth_phase = 0
        self.amp_phase = 0
        self.fwidth_phase = 0 
        self.awidth_phase = 0
        self.fbound_phase = 0 
        self.abound_phase = 0

        self.channels = channels
        self.samplerate = samplerate

        self.wavetable = self.points.towavetable().data

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef object _play(self, int length):
        cdef int i = 0
        cdef double sample, freq, amp, width, fwidth, awidth, fbound, abound
        cdef double ilength = 1.0 / length

        cdef int freq_boundry = max(len(self.freq)-1, 1)
        cdef int xwidth_boundry = max(len(self.xwidth)-1, 1)
        cdef int ywidth_boundry = max(len(self.ywidth)-1, 1)
        cdef int amp_boundry = max(len(self.amp)-1, 1)
        cdef int wt_boundry = max(len(self.wavetable)-1, 1)
        cdef int fwidth_boundry = max(len(self.fwidth)-1, 1)
        cdef int awidth_boundry = max(len(self.awidth)-1, 1)
        cdef int fbound_boundry = max(len(self.fbound)-1, 1)
        cdef int abound_boundry = max(len(self.abound)-1, 1)

        cdef double freq_phase_inc = ilength * freq_boundry
        cdef double xwidth_phase_inc = ilength * xwidth_boundry
        cdef double ywidth_phase_inc = ilength * ywidth_boundry
        cdef double amp_phase_inc = ilength * amp_boundry
        cdef double fwidth_phase_inc = ilength * fwidth_boundry
        cdef double awidth_phase_inc = ilength * awidth_boundry
        cdef double fbound_phase_inc = ilength * fbound_boundry
        cdef double abound_phase_inc = ilength * abound_boundry

        cdef double wt_phase_inc = (1.0 / self.samplerate) * self.wtsize
        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')

        fwidth = interpolation._linear_point(self.fwidth, self.fwidth_phase)
        awidth = interpolation._linear_point(self.awidth, self.awidth_phase)
        fbound = interpolation._linear_point(self.fbound, self.fbound_phase)
        abound = interpolation._linear_point(self.abound, self.abound_phase)

        cdef double freqd = 0
        cdef double ampd = 0

        for i in range(length):
            freq = self.freq_interpolator(self.freq, self.freq_phase)
            amp = interpolation._linear_point(self.amp, self.amp_phase)
            sample = interpolation._hermite_point(self.wavetable, self.wt_phase) * amp

            freq = freq + freqd
            amp = amp + ampd

            self.freq_phase += freq_phase_inc
            self.xwidth_phase += xwidth_phase_inc
            self.ywidth_phase += ywidth_phase_inc
            self.amp_phase += amp_phase_inc
            self.wt_phase += freq * wt_phase_inc
            self.fwidth_phase += fwidth_phase_inc
            self.awidth_phase += awidth_phase_inc
            self.fbound_phase += fbound_phase_inc
            self.abound_phase += abound_phase_inc

            if self.wt_phase >= wt_boundry:
                freqd = max(-fbound, min(freqd + rand.rand(-fwidth, fwidth), fbound))
                ampd = max(-abound, min(ampd + rand.rand(-awidth, awidth), abound))
                xwidth = interpolation._linear_point(self.xwidth, self.xwidth_phase)
                ywidth = interpolation._linear_point(self.ywidth, self.ywidth_phase)

                fwidth = interpolation._linear_point(self.fwidth, self.fwidth_phase)
                awidth = interpolation._linear_point(self.awidth, self.awidth_phase)
                fbound = interpolation._linear_point(self.fbound, self.fbound_phase)
                abound = interpolation._linear_point(self.abound, self.abound_phase)

                self.points.drink(xwidth, ywidth, -1, 1)
                self.wavetable = self.points.towavetable().data

            while self.wt_phase >= wt_boundry:
                self.wt_phase -= wt_boundry

            while self.amp_phase >= amp_boundry:
                self.amp_phase -= amp_boundry

            while self.freq_phase >= freq_boundry:
                self.freq_phase -= freq_boundry

            while self.xwidth_phase >= xwidth_boundry:
                self.xwidth_phase -= xwidth_boundry

            while self.ywidth_phase >= ywidth_boundry:
                self.ywidth_phase -= ywidth_boundry

            while self.fwidth_phase >= fwidth_boundry:
                self.fwidth_phase -= fwidth_boundry

            while self.awidth_phase >= awidth_boundry:
                self.awidth_phase -= awidth_boundry

            while self.fbound_phase >= fbound_boundry:
                self.fbound_phase -= fbound_boundry

            while self.abound_phase >= abound_boundry:
                self.abound_phase -= abound_boundry

            for channel in range(self.channels):
                out[i][channel] = sample

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

