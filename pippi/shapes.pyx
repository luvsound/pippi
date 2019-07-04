#cython: language_level=3

from pippi.wavetables cimport Wavetable, to_window, to_wavetable
from pippi.interpolation cimport _linear_pos, _linear_point
from pippi.rand cimport rand, randint
from pippi.soundbuffer cimport SoundBuffer
from pippi.defaults cimport DEFAULT_SAMPLERATE, DEFAULT_CHANNELS

from libc cimport math

cimport numpy as np
import numpy as np

MIN_WT_FREQ = 0.3
MAX_WT_FREQ = 12

MIN_SYNTH_FREQ = 40
MAX_SYNTH_FREQ = 15000

cpdef list onsets(double length, object density, object periodicity, object stability, double minfreq, double maxfreq):
    cdef double[:] _density = to_window(density)
    cdef double[:] _periodicity = to_window(periodicity)
    cdef double[:] _stability = to_window(stability)

    cdef list out = [0]
    cdef double elapsed=0, interval=0, pos=0, d=0, p=0, s=0
    cdef double longinterval = 1.0/minfreq
    cdef double shortinterval = 1.0/maxfreq
    cdef double intervalwidth = longinterval - shortinterval

    while elapsed < length:
        pos = elapsed / length
        s = 1 - _linear_pos(_stability, pos)
        s = math.log(s * (math.e-1) + 1)

        if s > rand(0,1):
            d = _linear_pos(_density, pos)
            p = 1 - _linear_pos(_periodicity, pos)

            interval = min((d * intervalwidth) + shortinterval + rand(intervalwidth * -p, intervalwidth * p), shortinterval)

        out += [ interval ]
        elapsed += interval

    return out

cpdef SoundBuffer synth(
        object wt, 
        double length=1, 
        object density=0.5, 
        object periodicity=0.5, 
        object stability=0.5, 
        double minfreq=0, 
        double maxfreq=0, 
        int samplerate=DEFAULT_SAMPLERATE, 
        int channels=DEFAULT_CHANNELS
    ):

    if minfreq <= 0:
        minfreq = MIN_SYNTH_FREQ

    if maxfreq <= 0:
        maxfreq = MAX_SYNTH_FREQ

    cdef unsigned int framelength = <unsigned int>(length * samplerate)
    cdef double[:] _wt = to_wavetable(wt)
    cdef double[:,:] out = np.zeros((framelength, channels), dtype='d')
    cdef double[:] _density = to_window(density)
    cdef double[:] _periodicity = to_window(periodicity)
    cdef double[:] _stability = to_window(stability)

    cdef unsigned int wt_length = len(_wt)
    cdef unsigned int wt_boundry = max(wt_length-1, 1)

    cdef int i=0, c=0
    cdef double isamplerate = 1.0/samplerate
    cdef double pos=0, d=0, p=0, s=0, freq=1, phase=0, sample=0
    cdef double freqwidth = maxfreq - minfreq

    d = _density[0]
    p = 1 - _periodicity[0]
    freq = max((d * freqwidth) + minfreq + rand(freqwidth * -p, freqwidth * p), minfreq)

    for i in range(framelength):
        pos = <double>i / <double>length
        sample = _linear_point(_wt, phase)

        for c in range(channels):
            out[i,c] = sample

        phase += isamplerate * wt_boundry * freq

        s = 1 - _linear_pos(_stability, pos)
        s = math.log(s * (math.e-1) + 1)
        if phase >= wt_boundry and s > rand(0,1):
            d = _linear_pos(_density, pos)
            p = 1 - _linear_pos(_periodicity, pos)
            freq = max((d * freqwidth) + minfreq + rand(freqwidth * -p, freqwidth * p), minfreq)

        while phase >= wt_boundry:
            phase -= wt_boundry

    return SoundBuffer(out, samplerate=samplerate, channels=channels)

cdef double[:] _table(double[:] out, unsigned int length, double[:] wt, double[:] density, double[:] periodicity, double[:] stability, double maxfreq, double minfreq, int samplerate):
    cdef unsigned int wt_length = len(wt)
    cdef unsigned int wt_boundry = max(wt_length-1, 1)

    cdef int i=0
    cdef double isamplerate = 1.0/samplerate
    cdef double pos=0, d=0, p=0, s=0, freq=1, phase=0
    cdef double freqwidth = maxfreq - minfreq

    d = density[0]
    p = 1 - periodicity[0]
    freq = max((d * freqwidth) + minfreq + rand(freqwidth * -p, freqwidth * p), minfreq)

    for i in range(length):
        pos = <double>i / <double>length
        out[i] = _linear_point(wt, phase)

        phase += isamplerate * wt_boundry * freq

        s = 1 - _linear_pos(stability, pos)
        s = math.log(s * (math.e-1) + 1)
        if phase >= wt_boundry and s > rand(0,1):
            d = _linear_pos(density, pos)
            d = math.log(d * (math.e-1) + 1)
            p = 1 - _linear_pos(periodicity, pos)
            #p = math.log(p * (math.e-1) + 1)
            freq = max((d * freqwidth) + minfreq + rand(freqwidth * -p, freqwidth * p), minfreq)

        while phase >= wt_boundry:
            phase -= wt_boundry

    return out

cpdef Wavetable win(object waveform, double length=1, object density=0.5, object periodicity=0.5, object stability=0.5, double minfreq=0, double maxfreq=0, int samplerate=DEFAULT_SAMPLERATE):
    if minfreq <= 0:
        minfreq = MIN_WT_FREQ

    if maxfreq <= 0:
        maxfreq = MAX_WT_FREQ

    cdef double[:] _wt = to_window(waveform)
    cdef double[:] _density = to_window(density)
    cdef double[:] _periodicity = to_window(periodicity)
    cdef double[:] _stability = to_window(stability)

    cdef unsigned int framelength = <unsigned int>(length * samplerate)
    cdef double[:] out = np.zeros(framelength, dtype='d')

    return Wavetable(_table(out, framelength, _wt, _density, _periodicity, _stability, maxfreq, minfreq, samplerate))

cpdef Wavetable wt(object waveform, double length=1, object density=0.5, object periodicity=0.5, object stability=0.5, double minfreq=0, double maxfreq=0, int samplerate=DEFAULT_SAMPLERATE):
    if minfreq <= 0:
        minfreq = MIN_WT_FREQ

    if maxfreq <= 0:
        maxfreq = MAX_WT_FREQ

    cdef double[:] _wt = to_wavetable(waveform)
    cdef double[:] _density = to_window(density)
    cdef double[:] _periodicity = to_window(periodicity)
    cdef double[:] _stability = to_window(stability)

    cdef unsigned int framelength = <unsigned int>(length * samplerate)
    cdef double[:] out = np.zeros(framelength, dtype='d')

    return Wavetable(_table(out, framelength, _wt, _density, _periodicity, _stability, maxfreq, minfreq, samplerate))

