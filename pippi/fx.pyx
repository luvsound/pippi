#cython: language_level=3

import numbers
import random
import math

cimport cython
from cython.parallel import prange
import numpy as np
cimport numpy as np

from pippi cimport fft
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport wavetables
from pippi.interpolation cimport _linear_point, _linear_pos
from pippi.dsp cimport _mag
from pippi cimport soundpipe
from cpython cimport bool

cdef double MINDENSITY = 0.001

cdef double[:,:] _crossfade(double[:,:] out, double[:,:] a, double[:,:] b, double[:] curve):
    cdef unsigned int length = len(a)
    cdef int channels = a.shape[1]
    cdef double pos = 0
    cdef double p = 0

    for i in range(length):
        pos = <double>i / <double>length
        p = _linear_pos(curve, pos)
        for c in range(channels):
            out[i,c] = (a[i,c] * p) + (b[i,c] * (1-p))

    return out

cpdef SoundBuffer crossfade(SoundBuffer a, SoundBuffer b, object curve=None):
    if len(a) != len(b):
        raise TypeError('Lengths do not match')
    if curve is None:
        curve = 'saw'
    cdef double[:] _curve = wavetables.Wavetable(curve, 0, 1).data
    cdef double[:,:] out = np.zeros((len(a), a.channels), dtype='d')
    return SoundBuffer(_crossfade(out, a.frames, b.frames, _curve), channels=a.channels, samplerate=a.samplerate)

cpdef SoundBuffer crush(SoundBuffer snd, object bitdepth=None, object samplerate=None):
    if bitdepth is None:
        bitdepth = random.triangular(0, 16)
    if samplerate is None:
        samplerate = random.triangular(0, snd.samplerate)
    cdef double[:] _bitdepth = wavetables.to_window(bitdepth)
    cdef double[:] _samplerate = wavetables.to_window(samplerate)
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    return SoundBuffer(soundpipe._bitcrush(snd.frames, out, _bitdepth, _samplerate, len(snd), snd.channels))

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _distort(double[:,:] snd, double[:,:] out):
    """ Non-linear distortion ported from supercollider """
    cdef int i=0, c=0
    cdef unsigned int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef double s = 0

    for i in range(framelength):
        for c in range(channels):
            s = snd[i,c]
            if s > 0:
                out[i,c] = s / (1.0 + abs(s))
            else:
                out[i,c] = s / (1.0 - s)

    return out

cpdef SoundBuffer distort(SoundBuffer snd):
    """ Non-linear distortion ported from supercollider """
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    return SoundBuffer(_distort(snd.frames, out))

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _softclip(double[:,:] snd, double[:,:] out):
    """ Soft clip ported from supercollider """
    cdef int i=0, c=0
    cdef unsigned int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef double mags=0, s=0

    for i in range(framelength):
        for c in range(channels):
            mags = abs(snd[i,c])
            s = snd[i,c]
            if mags <= 0.5:
                out[i,c] = s
            else:
                out[i,c] = (mags - 0.25) / s

    return out

cpdef SoundBuffer softclip(SoundBuffer snd):
    """ Soft clip ported from supercollider """
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    return SoundBuffer(_softclip(snd.frames, out))

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _crossover(double[:,:] snd, double[:,:] out, double[:] amount, double[:] smooth, double[:] fade):
    """ Crossover distortion ported from the supercollider CrossoverDistortion ugen """
    cdef int i=0, c=0
    cdef unsigned int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef double s=0, pos=0, a=0, f=0, m=0

    for i in range(framelength):
        pos = <double>i / <double>framelength
        a = _linear_pos(amount, pos)
        m = _linear_pos(smooth, pos)
        f = _linear_pos(fade, pos)

        for c in range(channels):
            s = abs(snd[i,c]) - a
            if s < 0:
                s *= (1.0 + (s * f)) * m

            if snd[i,c] < 0:
                s *= -1

            out[i,c] = s

    return out

cpdef SoundBuffer crossover(SoundBuffer snd, object amount, object smooth, object fade):
    """ Crossover distortion ported from the supercollider CrossoverDistortion ugen """
    cdef double[:] _amount = wavetables.to_window(amount)
    cdef double[:] _smooth = wavetables.to_window(smooth)
    cdef double[:] _fade = wavetables.to_window(fade)
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    return SoundBuffer(_crossover(snd.frames, out, _amount, _smooth, _fade))

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _norm(double[:,:] snd, double ceiling):
    cdef int i = 0
    cdef int c = 0
    cdef int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef double normval = 1
    cdef double maxval = _mag(snd)

    normval = ceiling / maxval
    for i in range(framelength):
        for c in range(channels):
            snd[i,c] *= normval

    return snd

cpdef SoundBuffer norm(SoundBuffer snd, double ceiling):
    snd.frames = _norm(snd.frames, ceiling)
    return snd

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _vspeed(double[:,:] snd, double[:] chan, double[:,:] out, double[:] lfo, double minspeed, double maxspeed, int samplerate):
    cdef int i = 0
    cdef int c = 0
    cdef int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef double speed = 0
    cdef double posinc = 1.0 / <double>framelength
    cdef double pos = 0
    cdef double lfopos = 0

    for c in range(channels):
        for i in range(framelength):
            chan[i] = snd[i,c]

        pos = 0
        lfopos = 0
        for i in range(framelength):
            speed = _linear_point(lfo, lfopos) * (maxspeed - minspeed) + minspeed
            out[i,c] = _linear_point(chan, pos)
            pos += posinc * speed
            lfopos += posinc

    return out

cpdef SoundBuffer vspeed(SoundBuffer snd, object lfo, double minspeed, double maxspeed):
    cdef double[:] _lfo = wavetables.to_wavetable(lfo)
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    cdef double[:] chan = np.zeros(len(snd), dtype='d')
    snd.frames = _vspeed(snd.frames, chan, out, _lfo, minspeed, maxspeed, snd.samplerate)
    return snd

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _widen(double[:,:] snd, double[:,:] out, double[:] width):
    cdef double mid, w, pos
    cdef int channels = snd.shape[1]
    cdef int length = len(snd)
    cdef int i, c, d=0

    for i in range(length-1):
        pos = <double>i / length
        w = _linear_pos(width, pos)
        mid = (1.0-w) / (1.0 + w)
        for c in range(channels):
            d = c + 1
            while d > channels:
                d -= channels
            out[i,c] = snd[i+1,c] + mid * snd[i+1,d]

    return out

cpdef SoundBuffer widen(SoundBuffer snd, object width=1):
    cdef double[:] _width = wavetables.to_window(width)
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    return SoundBuffer(_widen(snd.frames, out, _width), samplerate=snd.samplerate, channels=snd.channels)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _delay(double[:,:] snd, double[:,:] out, int delayframes, double feedback):
    cdef int i = 0
    cdef int c = 0
    cdef int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef int delayindex = 0
    cdef double sample = 0

    for i in range(framelength):
        delayindex = i - delayframes
        for c in range(channels):
            if delayindex < 0:
                sample = snd[i,c]
            else:
                sample = snd[delayindex,c] * feedback
                snd[i,c] += sample
            out[i,c] = sample

    return out

cpdef SoundBuffer delay(SoundBuffer snd, double delaytime, double feedback):
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    cdef int delayframes = <int>(snd.samplerate * delaytime)
    snd.frames = _delay(snd.frames, out, delayframes, feedback)
    return snd


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(False)
cdef double[:,:] _vdelay(double[:,:] snd, 
                         double[:,:] out, 
                         double[:] lfo, 
                         double[:,:] delayline, 
                         double mindelay, 
                         double maxdelay, 
                         double feedback, 
                         int samplerate):
    cdef int i = 0
    cdef int c = 0
    cdef double pos = 0
    cdef int framelength = len(snd)
    cdef int delaylinelength = len(delayline)
    cdef int channels = snd.shape[1]
    cdef int delayindex = 0
    cdef int delayindexnext = 0
    cdef int delaylineindex = 0
    cdef double sample = 0
    cdef double output = 0
    cdef double delaytime = 0
    cdef int delayframes = 0

    """
        double interp_delay(double n, double buffer[], int L, current) {
            int t1, t2;
            t1 = current + n;
            t1 %= L
            t2 = t1 + 1
            t2 %= L

            return buffer[t1] + (n - <int>n) * (buffer[t2] - buffer[t1]);
        }

        t1 = i + delaytimeframes
        t1 %= delaylinelength
        t2 = t1 + 1
        t2 %= delaylinelength

    for i in range(framelength):
        pos = <double>i / <double>framelength
        delaytime = (_linear_point(lfo, pos) * (maxdelay-mindelay) + mindelay) * samplerate
        delayindex = delaylineindex + <int>delaytime
        delayindex %= delaylinelength
        delayindexnext = delayindex + 1
        delayindexnext %= delaylinelength

        for c in range(channels):
            delayline[delaylineindex,c] += snd[i,c] * feedback
            sample = delayline[delayindex,c] + ((delaytime - <int>delaytime) * (delayline[delayindexnext,c] + delayline[delayindex,c]))
            out[i,c] = sample + snd[i,c]

        delaylineindex -= 1
        delaylineindex %= delaylinelength
        #print(delaylineindex, delayindex)
    """

    delayindex = 0

    for i in range(framelength):
        pos = <double>i / <double>framelength
        delaytime = (_linear_point(lfo, pos) * (maxdelay-mindelay) + mindelay) * samplerate
        delayreadindex = <int>(i - delaytime)
        for c in range(channels):
            sample = snd[i,c]

            if delayreadindex >= 0:
                output = snd[delayreadindex,c] * feedback
                sample += output

            delayindex += 1
            delayindex %= delaylinelength

            delayline[delayindex,c] = output

            out[i,c] = sample

    return out

cpdef SoundBuffer vdelay(SoundBuffer snd, object lfo, double mindelay, double maxdelay, double feedback):
    cdef double[:] lfo_wt = wavetables.to_wavetable(lfo, 4096)
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    cdef int maxdelayframes = <int>(snd.samplerate * maxdelay)
    cdef double[:,:] delayline = np.zeros((maxdelayframes, snd.channels), dtype='d')
    snd.frames = _vdelay(snd.frames, out, lfo_wt, delayline, mindelay, maxdelay, feedback, snd.samplerate)
    return snd


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _mdelay(double[:,:] snd, double[:,:] out, int[:] delays, double feedback):
    cdef int i = 0
    cdef int c = 0
    cdef int j = 0
    cdef int framelength = len(snd)
    cdef int numdelays = len(delays)
    cdef int channels = snd.shape[1]
    cdef int delayindex = 0
    cdef double sample = 0
    cdef double dsample = 0
    cdef double output = 0
    cdef int delaylinestart = 0
    cdef int delaylinepos = 0
    cdef int delayreadindex = 0

    cdef int delaylineslength = sum(delays)
    cdef double[:,:] delaylines = np.zeros((delaylineslength, channels), dtype='d')
    cdef int[:] delaylineindexes = np.zeros(numdelays, dtype='i')

    for i in range(framelength):
        for c in range(channels):
            sample = snd[i,c]
            delaylinestart = 0
            for j in range(numdelays):
                delayreadindex = i - delays[j]
                delayindex = delaylineindexes[j]
                delaylinepos = delaylinestart + delayindex
                output = delaylines[delaylinepos,c]

                if delayreadindex < 0:
                    dsample = 0
                else:
                    dsample = snd[delayreadindex,c] * feedback
                    output += dsample
                    sample += output

                delayindex += 1
                delayindex %= delays[j]

                delaylines[delaylinepos,c] = output
                delaylineindexes[j] = delayindex
                delaylinestart += delays[j]

            out[i,c] = sample

    return out

cpdef SoundBuffer mdelay(SoundBuffer snd, list delays, double feedback):
    cdef double[:,:] out = np.zeros((len(snd), snd.channels), dtype='d')
    cdef int numdelays = len(delays)
    cdef double delay
    cdef int[:] delayframes = np.array([ snd.samplerate * delay for delay in delays ], dtype='i')
    snd.frames = _mdelay(snd.frames, out, delayframes, feedback)
    return snd


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _fir(double[:,:] snd, double[:,:] out, double[:] impulse, bint norm=True):
    cdef int i=0, c=0, j=0
    cdef int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef int impulselength = len(impulse)
    cdef double maxval     

    if norm:
        maxval = _mag(snd)

    for i in prange(framelength, nogil=True):
        for c in range(channels):
            for j in range(impulselength):
                out[i+j,c] += snd[i,c] * impulse[j]

    if norm:
        return _norm(out, maxval)
    else:
        return out

cpdef SoundBuffer fir(SoundBuffer snd, object impulse, bint normalize=True):
    cdef double[:] impulsewt = wavetables.to_window(impulse)
    cdef double[:,:] out = np.zeros((len(snd)+len(impulsewt)-1, snd.channels), dtype='d')
    return SoundBuffer(_fir(snd.frames, out, impulsewt, normalize), channels=snd.channels, samplerate=snd.samplerate)

cpdef Wavetable envelope_follower(SoundBuffer snd, double window=0.015):
    cdef int blocksize = <int>(window * snd.samplerate)
    cdef int length = len(snd)
    cdef int barrier = length - blocksize
    cdef double[:] flat = np.ravel(np.array(snd.remix(1).frames, dtype='d'))
    cdef double val = 0
    cdef int i, j, ei = 0
    cdef int numblocks = <int>(length / blocksize)
    cdef double[:] env = np.zeros(numblocks, dtype='d')

    while i < barrier:
        val = 0
        for j in range(blocksize):
            val = max(val, abs(flat[i+j]))

        env[ei] = val

        i += blocksize
        ei += 1

    return Wavetable(env)

cpdef SoundBuffer lpf(SoundBuffer snd, object freq):
    cdef double[:] _freq = wavetables.to_window(freq)
    return SoundBuffer(soundpipe.butlp(snd.frames, _freq), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer hpf(SoundBuffer snd, object freq):
    cdef double[:] _freq = wavetables.to_window(freq)
    return SoundBuffer(soundpipe.buthp(snd.frames, _freq), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer bpf(SoundBuffer snd, object freq):
    cdef double[:] _freq = wavetables.to_window(freq)
    return SoundBuffer(soundpipe.butbp(snd.frames, _freq), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer brf(SoundBuffer snd, object freq):
    cdef double[:] _freq = wavetables.to_window(freq)
    return SoundBuffer(soundpipe.butbr(snd.frames, _freq), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer compressor(SoundBuffer snd, double ratio=4, double threshold=-30, double attack=0.2, double release=0.2):
    return SoundBuffer(soundpipe.compressor(snd.frames, ratio, threshold, attack, release), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer saturator(SoundBuffer snd, double drive=10, double offset=0, bint dcblock=True):
    return SoundBuffer(soundpipe.saturator(snd.frames, drive, offset, dcblock), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer paulstretch(SoundBuffer snd, stretch=1, windowsize=1):
    return SoundBuffer(soundpipe.paulstretch(snd.frames, windowsize, stretch, snd.samplerate), channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer mincer(SoundBuffer snd, double length, object position, object pitch, double amp=1, int wtsize=4096):
    cdef double[:] time_lfo = wavetables.to_window(position)
    cdef double[:] pitch_lfo = wavetables.to_window(pitch)
    return SoundBuffer(soundpipe.mincer(snd.frames, length, time_lfo, amp, pitch_lfo, wtsize, snd.samplerate), channels=snd.channels, samplerate=snd.samplerate)

cdef double[:,:] _to_impulse(object impulse, int channels):
    cdef double[:,:] _impulse
    cdef double[:] _wt

    if isinstance(impulse, str):
        _wt = wavetables.to_window(impulse)
        _impulse = np.hstack([ _wt for _ in range(channels) ])

    elif isinstance(impulse, Wavetable):
        _impulse = np.hstack([ np.reshape(impulse.data, (-1, 1)) for _ in range(channels) ])

    elif isinstance(impulse, SoundBuffer):
        if impulse.channels != channels:
            _impulse = impulse.remix(channels).frames
        else:
            _impulse = impulse.frames

    else:
        raise TypeError('Could not convolve impulse of type %s' % type(impulse))

    return _impulse

cpdef SoundBuffer convolve(SoundBuffer snd, object impulse, bint norm=True):
    cdef double[:,:] _impulse = _to_impulse(impulse, snd.channels)
    cdef double[:,:] out = fft.conv(snd.frames, _impulse)

    if norm:
        out = _norm(out, snd.mag)

    return SoundBuffer(out, channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer tconvolve(SoundBuffer snd, object impulse, bool normalize=True):
    cdef double[:,:] _impulse = _to_impulse(impulse, snd.channels)

    cdef int i=0, c=0, j=0
    cdef int framelength = len(snd)
    cdef int impulselength = len(_impulse)
    cdef double maxval     

    cdef double[:,:] out = np.zeros((framelength + impulselength, snd.channels), dtype='d')

    if normalize:
        maxval = _mag(snd.frames)

    for i in prange(framelength, nogil=True):
        for c in range(snd.channels):
            for j in range(impulselength):
                out[i+j,c] += snd.frames[i,c] * _impulse[j,c]

    if normalize:
        out = _norm(out, maxval)

    return SoundBuffer(out, channels=snd.channels, samplerate=snd.samplerate)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.initializedcheck(False)
@cython.cdivision(True)
cpdef SoundBuffer wconvolve(SoundBuffer snd, SoundBuffer impulse, object wsize=None, object grid=None, bool normalize=True):
    if wsize is None:
        wsize = 0.02

    if grid is None:
        grid = 'phasor'

    cdef double[:] _wsize = wavetables.to_window(wsize)
    cdef double[:] _grid = wavetables.to_window(grid)

    cdef double[:,:] _impulse = _to_impulse(impulse, snd.channels)

    cdef int i=0, c=0, j=0
    cdef int framelength = len(snd)
    cdef int impulselength = len(_impulse)
    cdef int windowlength 
    cdef double w = 1
    cdef int offset = 0
    cdef double maxval     
    cdef double g = 0
    cdef double pos = 0
    cdef int outlength = framelength + impulselength

    cdef double[:,:] out = np.zeros((outlength, snd.channels), dtype='d')

    if normalize:
        maxval = _mag(snd.frames)

    for i in prange(framelength, nogil=True):
        pos = <double>i/<double>framelength
        g = _linear_pos(_grid, pos)
        w = _linear_pos(_wsize, pos)
        windowlength = max(16, <int>(impulselength * w))
        offset = <int>(g * (impulselength-windowlength))
        for c in range(snd.channels):
            for j in range(windowlength):
                out[i+j,c] += snd.frames[i,c] * _impulse[j+offset,c]

    if normalize:
        out = _norm(out, maxval)

    return SoundBuffer(out, channels=snd.channels, samplerate=snd.samplerate)

cpdef SoundBuffer go(SoundBuffer snd, 
                          object factor,
                          double density=1, 
                          double wet=1,
                          double minlength=0.01, 
                          double maxlength=0.06, 
                          double minclip=0.4, 
                          double maxclip=0.8, 
                          object win=None
                    ):
    if wet <= 0:
        return snd

    cdef wavetables.Wavetable factors = None
    if not isinstance(factor, numbers.Real):
        factors = wavetables.Wavetable(factor)

    density = max(MINDENSITY, density)

    cdef double outlen = snd.dur + maxlength
    cdef SoundBuffer out = SoundBuffer(length=outlen, channels=snd.channels, samplerate=snd.samplerate)
    cdef wavetables.Wavetable window
    if win is None:
        window = wavetables.Wavetable(wavetables.HANN)
    else:
        window = wavetables.Wavetable(win)

    cdef double grainlength = random.triangular(minlength, maxlength)
    cdef double pos = 0
    cdef double clip
    cdef SoundBuffer grain

    while pos < outlen:
        grain = snd.cut(pos, grainlength)
        clip = random.triangular(minclip, maxclip)
        grain *= random.triangular(0, factor * wet)
        grain = grain.clip(-clip, clip)
        out.dub(grain * window.data, pos)

        pos += (grainlength/2) * (1/density)
        grainlength = random.triangular(minlength, maxlength)

    if wet > 0:
        out *= wet

    if wet < 1:
        out.dub(snd * abs(wet-1), 0)

    return out
