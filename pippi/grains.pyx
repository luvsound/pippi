#cython: language_level=3

from pippi.wavetables cimport HANN, PHASOR, to_window, to_wavetable, Wavetable
from pippi cimport interpolation
from pippi.soundbuffer cimport SoundBuffer
from libc.stdlib cimport rand, RAND_MAX, malloc, free
import numpy as np
cimport cython
from cpython cimport array
import array

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _speed(double speed, double[:,:] original, double[:,:] out, int channels) nogil:
    cdef unsigned int inlength = len(original)
    cdef unsigned int outlength = len(out)
    cdef double phase_inc = (1.0/inlength) * (inlength-1) * speed
    cdef double phase = 0, pos = 0
    cdef int c = 0, i = 0

    for i in range(outlength):
        for c in range(channels):
            out[i,c] = interpolation._linear_point(original[:,c], phase)

        phase += phase_inc * speed
        if phase >= inlength:
            break

    return out

cdef class Cloud:
    def __cinit__(self, 
            SoundBuffer snd, 
            object window=None, 
            object position=None,
            object amp=1.0,
            object speed=1.0, 
            object spread=0.0, 
            object jitter=0.0, 
            object grainlength=0.2, 
            object grid=None,
            object mask=None,
            unsigned int wtsize=4096,
        ):

        self.snd = snd.frames
        self.framelength = <unsigned int>len(snd)
        self.length = <double>(self.framelength / <double>snd.samplerate)
        self.channels = <unsigned int>snd.channels
        self.samplerate = <unsigned int>snd.samplerate

        self.wtsize = wtsize

        if window is None:
            window = 'sine'
        self.window = to_window(window)

        if position is None:
            self.position = Wavetable('phasor', 0, 1, window=True).data
        else:
            self.position = to_window(position)

        self.amp = to_window(amp)
        self.speed = to_window(speed)
        self.spread = to_window(spread)
        self.jitter = to_wavetable(jitter)
        self.grainlength = to_window(grainlength)

        if grid is None:
            self.grid = np.multiply(self.grainlength, 0.3)
        else:
            self.grid = to_window(grid)

        if mask is None:
            self.has_mask = False
        else:
            self.has_mask = True
            self.mask = array.array('i', mask)

    def play(self, double length):
        cdef double[:] grid = np.divide(self.grid, length)
        cdef unsigned int outframelength = <unsigned int>(self.samplerate * length)
        cdef double[:,:] out = np.zeros((outframelength, self.channels), dtype='d')
        cdef unsigned int write_pos=0
        cdef unsigned int read_pos=0
        cdef unsigned int grainlength
        cdef double pos = 0
        cdef double grainpos = 0
        cdef double panpos = 0
        cdef double sample = 0
        cdef double spread = 0
        cdef double speed, amp
        cdef unsigned int write_boundry = outframelength-1
        cdef unsigned int read_boundry = len(self.snd)-1
        cdef unsigned int masklength = 0
        cdef unsigned int count = 0

        cdef double minspeed = min(self.speed)
        cdef unsigned long maxgrainlength = <unsigned long>(max(self.grainlength) * self.samplerate)
        cdef double[:,:] grain = np.zeros((maxgrainlength, self.channels), dtype='d')
        cdef double[:,:] grainresamp
        cdef unsigned int resamplength

        if self.has_mask:
            masklength = <unsigned int>len(self.mask)

        while pos <= 1:
            write_pos = <unsigned int>(pos * write_boundry)
            write_jitter = <int>(interpolation._linear_pos(self.jitter, pos) * (rand()/<double>RAND_MAX) * self.samplerate)
            write_pos += max(-write_jitter, write_jitter)

            if self.has_mask and self.mask[<int>(count % masklength)] == 0:
                pos += interpolation._linear_pos(grid, pos)
                count += 1
                continue

            grainlength = <unsigned int>(interpolation._linear_pos(self.grainlength, pos) * self.samplerate)
            if write_pos + grainlength > write_boundry:
                break

            speed = interpolation._linear_pos(self.speed, pos)
            read_pos = <unsigned int>(interpolation._linear_pos(self.position, pos) * (read_boundry-grainlength))
            spread = interpolation._linear_pos(self.spread, pos)
            panpos = (rand()/<double>RAND_MAX) * spread + (0.5 - (spread * 0.5))
            pans = [panpos, 1-panpos]

            for i in range(grainlength):
                grainpos = <double>i / (grainlength-1)
                amp = <double>interpolation._linear_pos(self.amp, pos)
                amp *= interpolation._linear_pos(self.window, grainpos) 

                for c in range(self.channels):
                    panpos = pans[c % 2]
                    grain[i,c] = self.snd[read_pos+i, c] * amp

            if speed != 1:
                resamplength = <unsigned int>(grainlength * (1.0/speed))
                grainresamp = np.zeros((resamplength, self.channels), dtype='d')

                grainresamp = _speed(speed, grain, grainresamp, <int>self.channels)
                grainlength = <unsigned int>(grainlength * (1.0/speed))

                for i in range(resamplength):
                    if write_pos+i > write_boundry:
                        break

                    for c in range(self.channels):
                        out[write_pos+i, c] += grainresamp[i,c]

            else:
                for i in range(grainlength):
                    for c in range(self.channels):
                        out[write_pos+i, c] += grain[i,c]

            pos += interpolation._linear_pos(grid, pos)
            count += 1

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)


