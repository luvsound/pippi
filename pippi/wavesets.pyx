# cython: language_level=3, cdivision=True, wraparound=False, boundscheck=False, initializedcheck=False

from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport Wavetable, to_wavetable, to_window, SINE, SINEIN, SINEOUT
from pippi cimport interpolation
from pippi.rand cimport rand
from pippi.defaults cimport DEFAULT_CHANNELS, DEFAULT_SAMPLERATE
from pippi.fx cimport _norm
from pippi.dsp cimport _mag

from libc.math cimport signbit
from libc.stdlib cimport malloc, free
import numpy as np
cimport numpy as np

np.import_array()

cdef struct Wave:
    unsigned int start
    unsigned int end
    int length
    double mag

cdef class Waveset:
    def __cinit__(
            Waveset self, 
            object values=None, 
            int crossings=3, 
            int offset=-1,
            int limit=-1, 
            int modulo=1, 
            int samplerate=-1,
            list wavesets=None,
        ):

        self.samplerate = samplerate
        crossings = max(crossings, 2)

        if values is not None:
            self._load(values, crossings, offset, limit, modulo)
        elif wavesets is not None:
            self._import(wavesets)

    def __getitem__(self, position):
        return self.wavesets[position]

    def __iter__(self):
        return iter(self.wavesets)

    def __len__(self):
        return len(self.wavesets)

    cpdef Waveset copy(Waveset self):
        cdef Waveset copy = Waveset(samplerate=self.samplerate, wavesets=self.wavesets)
        copy.max_length = self.max_length
        copy.min_length = self.min_length
        return copy

    cdef void _import(Waveset self, list wavesets):
        cdef double[:] copy
        cdef int num_wavesets = len(wavesets)

        self.wavesets = []
        for i in range(num_wavesets):
            copy = np.array(wavesets[i], dtype='d')
            self.wavesets += [ copy ]

    cdef void _load(Waveset self, object values, int crossings, int offset, int limit, int modulo):
        cdef double[:] raw
        cdef double[:] waveset
        cdef double original_mag = 0
        cdef double val, last
        cdef int crossing_count=0, waveset_count=0, mod_count=0, waveset_output_count=0, offset_count=0
        cdef int i=1, start=0, end=0

        self.wavesets = []
        self.max_length = 0
        self.min_length = 0

        if isinstance(values, SoundBuffer):
            original_mag = _mag(values.frames)
            values = values.remix(1)
            raw = np.ravel(np.array(_norm(values.frames, original_mag), dtype='d'))
            if self.samplerate <= 0:
                self.samplerate = values.samplerate

        elif isinstance(values, Wavetable):
            raw = values.data

        else:
            raw = np.ravel(np.array(values, dtype='d'))

        if self.samplerate <= 0:
            self.samplerate = DEFAULT_SAMPLERATE

        cdef int length = len(raw)
        last = raw[0]

        while i < length:
            if (signbit(last) and not signbit(raw[i])) or (not signbit(last) and signbit(raw[i])):
                crossing_count += 1

                if crossing_count == crossings:
                    waveset_count += 1
                    mod_count += 1
                    crossing_count = 0

                    if mod_count == modulo:
                        mod_count = 0
                        end = i

                        if offset_count <= offset:
                            offset_count += 1
                            continue

                        self._slice(raw, start, end)
                        waveset_output_count += 1

                        if limit == waveset_output_count:
                            break

                    start = i

            last = raw[i]
            i += 1

        if end < length and limit < waveset_output_count:
            self._slice(raw, end, length)

    cdef void _slice(Waveset self, double[:] raw, int start, int end):
        cdef Wave* w = <Wave*>malloc(sizeof(Wave))
        w.start = start
        w.end = end
        w.length = end-start

        cdef int waveset_length = end-start
        waveset = np.zeros(waveset_length, dtype='d')
        waveset = raw[start:end]
        self.wavesets += [ waveset ]

        self.max_length = max(self.max_length, waveset_length)
        #self.max_length = max(self.max_length, w.length)

        if self.min_length == 0:
            self.min_length = waveset_length
            #self.min_length = w.length
        else:
            self.min_length = min(self.min_length, waveset_length)
            #self.min_length = min(self.min_length, w.length)


    cpdef void interleave(Waveset self, Waveset source):
        cdef int i = 0
        cdef list interleaved = []
        cdef int shortest = min(len(self), len(source))
        for i in range(shortest):
            interleaved += [ self.wavesets[i], source.wavesets[i] ]
        self.wavesets = interleaved

    cpdef SoundBuffer stretch(Waveset self, object factor=2.0):
        cdef list out = []
        cdef int i, repeat
        cdef int numwavesets = len(self.wavesets)
        cdef double pos = 0
        cdef double[:] stretched
        cdef double[:] curve = to_window(factor)

        for i in range(numwavesets):
            pos = <double>i / numwavesets
            repeat = <int>interpolation._linear_pos(curve, pos)
            if repeat == 1:
                out += [ self.wavesets[i] ]
            elif repeat < 1:
                continue
            else:
                stretched = np.tile(self.wavesets[i], repeat)
                out += [ stretched ]

        return self.render(out)

    cpdef void reverse(Waveset self):
        self.wavesets = list(reversed(self.wavesets))

    cpdef Waveset reversed(Waveset self):
        cdef Waveset out = self.copy()
        out.reverse()
        return out

    cpdef void retrograde(Waveset self):
        cdef int i, j, b, length
        cdef double[:] reverse

        for i in range(len(self.wavesets)):
            length = len(self.wavesets[i])
            reverse = np.zeros(length, dtype='d')

            for j in range(length):
                b = abs(j+1 - length)
                reverse[j] = self.wavesets[i][b]

            self.wavesets[i] = reverse

    cpdef void invert(Waveset self):
        pass

    cpdef SoundBuffer harmonic(Waveset self, list harmonics=None, list weights=None):
        if harmonics is None:
            harmonics = [1,2,3]

        if weights is None:
            weights = [1,0.5,0.25]

        cdef list out = []
        cdef int i, length, j, k, h, plength
        cdef double maxval
        cdef double[:] partial
        cdef double[:] cluster

        for i in range(len(self.wavesets)):
            length = len(self.wavesets[i])
            maxval = max(np.abs(self.wavesets[i])) 
            cluster = np.zeros(length, dtype='d')
            for h in harmonics:
                plength = length * h
                partial = np.zeros(plength, dtype='d')
                for j in range(h):
                    for k in range(length):
                        partial[k*j] = self.wavesets[i][k] * maxval

                partial = interpolation._linear(partial, length)

                for j in range(length):
                    cluster[j] += partial[j]

            for j in range(length):
                cluster[j] *= maxval

            out += [ cluster ]

        return self.render(out)

    cpdef SoundBuffer replace(Waveset self, object waveforms):
        cdef double[:] wt
        cdef list out = []
        cdef int i, wi, length
        cdef int numwavesets = len(self.wavesets)
        cdef int numwaveforms = len(waveforms)
        cdef double maxval, wmaxval, pos
        cdef double[:] replacement

        for i in range(numwavesets):
            pos = <double>i / numwavesets
            wi = <int>(pos * numwaveforms)
            length = len(self.wavesets[i])
            maxval = max(np.abs(self.wavesets[i])) 
            wt = to_wavetable(waveforms[wi])
            wmaxval = max(np.abs(wt)) 
            replacement = interpolation._linear(wt, length)

            for j in range(length):
                replacement[j] *= (maxval / wmaxval)

            out += [ replacement ]

        return self.render(out)

    cpdef SoundBuffer substitute(Waveset self, object waveform):
        cdef double[:] wt = to_wavetable(waveform)
        cdef list out = []
        cdef int i, length
        cdef double maxval
        cdef double[:] replacement

        for i in range(len(self.wavesets)):
            length = len(self.wavesets[i])
            maxval = max(np.abs(self.wavesets[i])) 
            replacement = interpolation._linear(wt, length)

            for j in range(length):
                replacement[j] *= maxval

            out += [ replacement ]

        return self.render(out)

    cpdef SoundBuffer morph(Waveset self, Waveset target, object curve=None):
        if curve is None:
            curve = SINE

        cdef double[:] wt = to_window(curve)
        cdef int slength = len(self)
        cdef int tlength = len(target)
        cdef int maxlength = max(slength, tlength)
        cdef int i=0, si=0, ti=0
        cdef double prob=0, pos=0
        cdef list out = []

        while i < maxlength:
            pos = <double>i / maxlength
            prob = interpolation._linear_pos(wt, pos)
            if rand(0,1) > prob:
                si = <int>(pos * slength)
                out += [ self[si] ]
            else:
                ti = <int>(pos * tlength)
                out += [ target[ti] ]

            i += 1

        return self.render(out)

    cpdef SoundBuffer render(Waveset self, list wavesets=None, int channels=-1, int samplerate=-1, int taper=0):
        channels = DEFAULT_CHANNELS if channels < 1 else channels
        samplerate = self.samplerate if samplerate < 1 else samplerate

        cdef double[:] fadein, fadeout

        if taper > 1:
            fadein = to_window(SINEIN, taper)
            fadeout = to_window(SINEOUT, taper)

        if wavesets is None:
            wavesets = self.wavesets

        cdef double mult = 1
        cdef int i=0, c=0, j=0, oi=0, wlength=0
        cdef long framelength = 0
        cdef int numsets = len(wavesets)
        for i in range(numsets):
            framelength += len(wavesets[i])

        cdef double[:,:] out = np.zeros((framelength, channels), dtype='d')        

        for i in range(numsets):
            wlength = len(wavesets[i])
            for j in range(wlength):
                if taper > 1 and j < taper:
                    mult = fadein[j]
                elif taper > 1 and j >= wlength - taper:
                    mult = fadeout[abs(wlength-j-taper)]
                else:
                    mult = 1

                for c in range(channels):
                    out[oi][c] = wavesets[i][j] * mult
                oi += 1

        return SoundBuffer(out, channels=channels, samplerate=samplerate)

    cpdef void normalize(Waveset self, double ceiling=1):
        cdef int i=0, j=0
        cdef double normval = 1
        cdef double maxval = 0 
        cdef int numsets = len(self.wavesets)

        for i in range(numsets):
            maxval = max(np.abs(self.wavesets[i])) 
            normval = ceiling / maxval
            for j in range(len(self.wavesets[i])):
                self.wavesets[i][j] *= normval

