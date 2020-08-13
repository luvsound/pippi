#cython: language_level=3

from pippi cimport interpolation
from pippi cimport wavetables
from pippi cimport shapes
from pippi cimport fx
from pippi.lists cimport _scaleinplace
from libc.stdlib cimport malloc, free
import numpy as np
cimport numpy as np

np.import_array()

DEF MINFREQ = 1.
DEF MAXFREQ = 20000.


cdef double[:,:] _extract_band(double[:,:] snd, double[:,:] out, double[:] minfreq, double[:] maxfreq):
    cdef sp_data* sp
    cdef sp_buthp* buthp1
    cdef sp_buthp* buthp2
    cdef sp_butlp* butlp1
    cdef sp_butlp* butlp2

    cdef int i = 0
    cdef int c = 0
    cdef double pos = 0

    cdef int length = len(snd)
    cdef int channels = snd.shape[1]

    cdef double sample = 0
    cdef double filtered = 0
    cdef double output = 0
    cdef double _minfreq, _maxfreq

    sp_create(&sp)

    for c in range(channels):
        sp_buthp_create(&buthp1)
        sp_buthp_create(&buthp2)
        sp_buthp_init(sp, buthp1)
        sp_buthp_init(sp, buthp2)

        sp_butlp_create(&butlp1)
        sp_butlp_create(&butlp2)
        sp_butlp_init(sp, butlp1)
        sp_butlp_init(sp, butlp2)

        for i in range(length):
            sample = snd[i,c]
            pos = <double>i / length
            _minfreq = interpolation._linear_pos(minfreq, pos)
            _maxfreq = interpolation._linear_pos(maxfreq, pos)

            if _maxfreq < MAXFREQ:
                buthp1.freq = _maxfreq
                buthp2.freq = _maxfreq
                sp_buthp_compute(sp, buthp1, &sample, &filtered)
                sp_buthp_compute(sp, buthp2, &filtered, &filtered)
            else:
                filtered = sample

            if _minfreq > MINFREQ:
                butlp1.freq = _minfreq
                butlp2.freq = _minfreq
                sp_butlp_compute(sp, butlp1, &filtered, &filtered)
                sp_butlp_compute(sp, butlp2, &filtered, &output)
            else:
                output = filtered

            out[i,c] = output

        sp_buthp_destroy(&buthp1)
        sp_buthp_destroy(&buthp2)

        sp_butlp_destroy(&butlp1)
        sp_butlp_destroy(&butlp2)

    sp_destroy(&sp)

    return out

cdef double mtof(double note):
    return 2**((note-69)/12.0) * 440.0

cdef double[:] _driftfreq(double[:] freq, double[:] curve):
    cdef int length = len(freq)
    cdef int i = 0
    for i in range(length):
        pos = <double>i / length
        freq[i] -= interpolation._linear_pos(curve, pos)
    return freq

cpdef list split(SoundBuffer snd, double interval=3, object drift=None, double driftwidth=0):
    cdef int length = len(snd)
    cdef int channels = snd.channels

    cdef list out = []
    cdef double[:,:] band = np.zeros((length, channels), dtype='d')

    cdef double[:] _minfreq
    cdef double[:] _maxfreq
    cdef double[:] _drift

    if drift is None:
        _drift = wavetables.to_window(0)
    else: 
        _drift = wavetables.to_window(drift)
        _drift = _scaleinplace(_drift, np.min(_drift), np.max(_drift), 0, driftwidth/2.0, False)

    _minfreq = wavetables.to_window(0)
    _maxfreq = _driftfreq(wavetables.to_window(mtof(interval)), _drift)
    band = _extract_band(snd.frames, band, _minfreq, _maxfreq)
    out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

    cdef double note = interval

    while mtof(note+interval) < MAXFREQ:
        _minfreq = _driftfreq(wavetables.to_window(mtof(note)), _drift)
        _maxfreq = _driftfreq(wavetables.to_window(mtof(note+interval)), _drift)
        band = _extract_band(snd.frames, band, _minfreq, _maxfreq)
        out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]
        note += interval

    if mtof(note) < MAXFREQ:
        _minfreq = _driftfreq(wavetables.to_window(mtof(note)), _drift)
        _maxfreq = wavetables.to_window(MAXFREQ)
        band = _extract_band(snd.frames, band, _minfreq, _maxfreq)
        out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

    return out


cpdef list customsplit(SoundBuffer snd, list freqs):
    cdef int length = len(snd)
    cdef int channels = snd.channels
    cdef int i = 0

    cdef list out = []
    cdef double[:,:] band = np.zeros((length, channels), dtype='d')

    cdef double[:] _minfreq
    cdef double[:] _maxfreq

    _minfreq = wavetables.to_window(0)
    _maxfreq = wavetables.to_window(freqs[0])
    band = _extract_band(snd.frames, band, _minfreq, _maxfreq)
    out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

    for i in range(len(freqs)-1):
        _minfreq = wavetables.to_window(freqs[i])
        _maxfreq = wavetables.to_window(freqs[i+1])
        band = _extract_band(snd.frames, band, _minfreq, _maxfreq)
        out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

    _minfreq = wavetables.to_window(freqs[-1])
    _maxfreq = wavetables.to_window(MAXFREQ)
    band = _extract_band(snd.frames, band, _minfreq, _maxfreq)
    out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

    return out

cpdef SoundBuffer spread(SoundBuffer snd, double amount=0.5):
    cdef SoundBuffer out = SoundBuffer(length=snd.dur, channels=snd.channels, samplerate=snd.samplerate)

    amount = max(min(0.5, amount), 0)

    cdef list bands = split(snd)
    for b in bands:
        curve = wavetables.Wavetable(shapes.win('hann', length=snd.dur/4), 0.5-amount, 0.5+amount)
        out.dub(b.pan(curve))

    return fx.norm(out, snd.mag)

