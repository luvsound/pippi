#cython: language_level=3

""" This is a port of Julius O Smith's `pluck.c` -- an implementation of digital waveguide synthesis.
    I've tried to preserve his original comments inline.

    The original can be found here: https://ccrma.stanford.edu/~jos/pmudw/pluck.c

    pluck.c - elementary waveguide simulation of plucked strings - JOS 6/6/92
"""

from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport to_window, to_wavetable
from pippi cimport interpolation
import numpy as np

cdef inline short DOUBLE_TO_SHORT(double x):
    return <int>(x*32768.0)

cdef class DelayLine:
    def __init__(self, int length):
        self.buf = np.zeros(length, dtype='int16')
        self.position = 0

cdef class Pluck:
    def __init__(self, double freq=220.0, double pick=0.1, double pickup=0.2, double amp=1, object seed=None, int samplerate=44100, int channels=2):
        self.state = 0
        self.freq = freq
        self.pick = pick
        self.pickup = pickup
        self.amp = amp
        self.samplerate = samplerate
        self.channels = channels

        self.rail_length = <int>(<double>samplerate / freq / 2.0 + 1.0)

        self.upper_rail = DelayLine(self.rail_length)
        self.lower_rail = DelayLine(self.rail_length)

        # Round pick position to nearest spatial sample.
        # A pick position at x = 0 is not allowed. 
        cdef int pickSample = <int>max(self.rail_length * pick, 1)
        cdef double upslope = <double>pickSample
        cdef double downslope = <double>(self.rail_length - pickSample - 1)

        if seed is None:
            self.seed = np.zeros(self.rail_length, dtype='d')

            for i in range(pickSample):
                self.seed[i] = upslope * i

            for i in range(pickSample, self.rail_length):
                self.seed[i] = downslope * (self.rail_length - 1 - i)
        else:
            self.seed = to_window(seed, self.rail_length)

        self.seed = np.interp(self.seed, (np.max(self.seed), np.min(self.seed)), (0, amp))

        # Initial conditions for the ideal plucked string.
        # "Past history" is measured backward from the end of the array.
        for i in range(self.rail_length):
            self.lower_rail.buf[i] = DOUBLE_TO_SHORT(0.5 * self.seed[i])

        for i in range(self.rail_length):
            self.upper_rail.buf[i] = DOUBLE_TO_SHORT(0.5 * self.seed[i])

        self.pickup_location = <int>(self.pickup * self.rail_length)

    cpdef short get_sample(Pluck self, DelayLine dline, int position):
        return dline.buf[(dline.position + position) % self.rail_length]

    cpdef double next_sample(Pluck self):
        cdef short yp0, ym0, ypM, ymM
        cdef short outsamp, outsamp1

        # Output at pickup location 
        # Returns spatial sample at location "position", where position zero
        # is equal to the current upper delay-line pointer position (x = 0).
        # In a right-going delay-line, position increases to the right, and
        # delay increases to the right => left = past and right = future.

        # Returns sample "position" samples into delay-line's past.
        # Position "0" points to the most recently inserted sample.
        outsamp = self.get_sample(self.upper_rail, self.pickup_location)

        # Returns spatial sample at location "position", where position zero
        # is equal to the current lower delay-line pointer position (x = 0).
        # In a left-going delay-line, position increases to the right, and
        # delay DEcreases to the right => left = future and right = past.
        outsamp1 = self.get_sample(self.lower_rail, self.pickup_location)

        outsamp += outsamp1

        ym0 = self.get_sample(self.lower_rail, 1) # Sample traveling into "bridge"
        ypM = self.get_sample(self.upper_rail, self.rail_length - 2) # Sample to "nut"

        ymM = -ypM                    # Inverting reflection at rigid nut 

        # Implement a one-pole lowpass with feedback coefficient = 0.5 
        # outsamp = 0.5 * outsamp + 0.5 * insamp 
        self.state = (self.state >> 1) + (ym0 >> 1)

        yp0 = -self.state  # Reflection at yielding bridge 

        # String state update 

        # Decrements current upper delay-line pointer position (i.e.
        # the wave travels one sample to the right), moving it to the
        # "effective" x = 0 position for the next iteration.  The
        # "bridge-reflected" sample from lower delay-line is then placed
        # into this position.

        # Decrement pointer and then update 
        self.upper_rail.position -= 1
        self.upper_rail.buf[self.upper_rail.position % self.rail_length] = yp0

        # Places "nut-reflected" sample from upper delay-line into
        # current lower delay-line pointer location (which represents
        # x = 0 position).  The pointer is then incremented (i.e. the
        # wave travels one sample to the left), turning the previous
        # position into an "effective" x = L position for the next
        # iteration.

        # Update and then increment pointer
        self.lower_rail.buf[self.lower_rail.position % self.rail_length] = ymM
        self.lower_rail.position += 1

        return <double>(outsamp / 32768.0) * self.amp


    cpdef SoundBuffer play(Pluck self, double length, object seed=None):
        cdef SoundBuffer out = SoundBuffer(length=length, channels=self.channels, samplerate=<int>self.samplerate)
        cdef int framelength = len(out)
        cdef double sample = 0
        cdef double[:] _seed

        if seed is not None:
            _seed = to_window(seed, self.rail_length)

            for i in range(self.rail_length):
                self.lower_rail.buf[i] += DOUBLE_TO_SHORT(0.5 * _seed[i])

            for i in range(self.rail_length):
                self.upper_rail.buf[i] += DOUBLE_TO_SHORT(0.5 * _seed[i])

        for i in range(framelength):
            sample = self.next_sample()
            for c in range(self.channels):
                out.frames[i][c] = sample
        
        return out
