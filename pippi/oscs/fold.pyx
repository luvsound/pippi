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


cdef class Fold:
    """ Folding wavetable oscilator
    """

    def __init__(
            self, 
            double[:] wavetable=None, 
            double[:] factors=None, 
            double freq=440, 
            double factFreq=1,
            double amp=1, 
            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.freq = freq
        self.factFreq = factFreq
        self.amp = amp

        self.channels = channels
        self.samplerate = samplerate
        self.wtsize = wtsize

        self.wavetable = wavetable
        self.factors = factors

    def play(self, double length):
        return self._play(length)

    cdef SoundBuffer _play(self, double length):
        cdef int framelength = <int>(length * self.samplerate)
        cdef int i
        cdef int channel = 0

        cdef double valWaveform, valNextWaveform, freq, factFreq
        cdef int cIndexWaveform = 0
        cdef double fracWaveform = 0

        cdef double valFactors, valNextFactors
        cdef int cIndexFactors = 0
        cdef double fracFactors = 0

        cdef double indexWaveform = 0
        cdef double indexFactors = 0

        cdef int lenWaveform = len(self.wavetable)
        cdef int lenFactors = len(self.factors)

        cdef double fold_out = 0
        cdef double last_value = 0 
        cdef int pos_thresh = 1 
        cdef int neg_thresh = -1 
        cdef int state = 1
        cdef double difference = 0

        cdef double[:,:] out = np.zeros((framelength, self.channels), dtype='d')

        for i in range(framelength):
            # Interp waveform wavetable
            cIndexWaveform = <int>indexWaveform % (lenWaveform - 1)
            valWaveform = self.wavetable[cIndexWaveform]
            valNextWaveform = self.wavetable[cIndexWaveform + 1]
            fracWaveform = indexWaveform - <int>indexWaveform
            valWaveform = (1.0 - fracWaveform) * valWaveform + fracWaveform * valNextWaveform

            # Interp factors wavetable
            cIndexFactors = <int>indexFactors % (lenFactors - 1)
            valFactors = self.factors[cIndexFactors]
            valNextFactors = self.factors[cIndexFactors + 1]
            fracFactors = indexFactors - <int>indexFactors
            valFactors = (1.0 - fracFactors) * valFactors + fracFactors * valNextFactors
            valWaveform *= valFactors

            # Do the folding 
            # the magic is ripped from guest's posts on muffwiggler: 
            # http://www.muffwiggler.com/forum/viewtopic.php?p=1586526#1586526
            difference = valWaveform - last_value
            last_value = valWaveform
            if state == 1:
                fold_out -= difference
            else:
                fold_out += difference

            if fold_out >= pos_thresh:
                state ^= 1
                fold_out = pos_thresh - (fold_out - pos_thresh)
            elif fold_out <= neg_thresh:
                state ^= 1
                fold_out = neg_thresh - (fold_out - neg_thresh)

            for channel in range(self.channels):
                out[i][channel] = self.amp * fold_out

            indexWaveform += self.freq * lenWaveform * (1.0 / self.samplerate)
            indexFactors += self.factFreq * lenFactors * (1.0 / self.samplerate)

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

