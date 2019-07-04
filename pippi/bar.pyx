#cython: language_level=3

from pippi.soundpipe cimport _bar
from pippi cimport wavetables
from pippi.soundbuffer cimport SoundBuffer
import numpy as np
cimport numpy as np

cdef inline int DEFAULT_SAMPLERATE = 44100
cdef inline int DEFAULT_CHANNELS = 2

cdef class Bar:
    def __cinit__(
            self, 
            object amp=1.0, 
            double stiffness=3.0,
            double decay=3.0,
            double leftclamp=1, 
            double rightclamp=1,
            double scan=0.25,
            double barpos=0.2,
            double velocity=500.0,
            double width=0.05,
            double loss=0.001,
            double phase=0,

            int wtsize=4096,
            int channels=DEFAULT_CHANNELS,
            int samplerate=DEFAULT_SAMPLERATE,
        ):

        self.wtsize = wtsize
        self.amp = wavetables.to_window(amp, self.wtsize)

        self.stiffness = stiffness
        self.decay = decay
        self.leftclamp = leftclamp
        self.rightclamp = rightclamp
        self.scan = scan
        self.barpos = barpos
        self.velocity = velocity
        self.width = width
        self.loss = loss

        self.channels = channels
        self.samplerate = samplerate

    def play(self, length):
        framelength = <int>(length * self.samplerate)
        return self._play(framelength)

    cdef SoundBuffer _play(self, int length):
        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')
        return SoundBuffer(_bar(out, length, self.amp, self.stiffness, self.decay, self.leftclamp, self.rightclamp, self.scan, self.barpos, self.velocity, self.width, self.loss, self.channels), channels=self.channels, samplerate=self.samplerate)


