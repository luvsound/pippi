#cython: language_level=3

from pippi cimport interpolation
from pippi cimport wavetables
from libc.stdlib cimport malloc, free
import numpy as np


cdef double[:,:] _extract_band(double[:,:] snd, double[:,:] out, double[:] minfreq, double[:] maxfreq):
    cdef sp_data* sp
    cdef sp_bal* bal
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
        sp_bal_create(&bal)
        sp_bal_init(sp, bal)

        sp_buthp_create(&buthp1)
        sp_buthp_create(&buthp2)
        sp_buthp_init(sp, buthp1)
        sp_buthp_init(sp, buthp2)

        sp_butlp_create(&butlp1)
        sp_butlp_create(&butlp2)
        sp_butlp_init(sp, butlp1)
        sp_butlp_init(sp, butlp2)

        for i in range(length):
            pos = <double>i / <double>length
            _minfreq = interpolation._linear_pos(minfreq, pos)
            _maxfreq = interpolation._linear_pos(maxfreq, pos)

            buthp1.freq = _maxfreq
            buthp2.freq = _maxfreq

            butlp1.freq = _minfreq
            butlp2.freq = _minfreq

            sample = <double>snd[i,c]

            sp_buthp_compute(sp, buthp1, &sample, &filtered)
            sp_buthp_compute(sp, buthp2, &filtered, &filtered)
            sp_butlp_compute(sp, butlp1, &filtered, &filtered)
            sp_butlp_compute(sp, butlp2, &filtered, &filtered)
            sp_bal_compute(sp, bal, &filtered, &sample, &output)

            out[i,c] = <double>output

        sp_bal_destroy(&bal)

        sp_buthp_destroy(&buthp1)
        sp_buthp_destroy(&buthp2)

        sp_butlp_destroy(&butlp1)
        sp_butlp_destroy(&butlp2)

    sp_destroy(&sp)

    return out

cpdef list split(SoundBuffer snd, double bandwidth=100, double drift=0):
    cdef int length = len(snd)
    cdef int channels = snd.channels

    cdef list out = []
    cdef double[:,:] band = np.zeros((length, channels), dtype='d')

    cdef double[:] minfreq
    cdef double[:] maxfreq

    cdef double freq = 0

    while freq+bandwidth < 20000:
        minfreq = wavetables.to_window(freq)
        maxfreq = wavetables.to_window(freq + bandwidth)
        band = _extract_band(snd.frames, band, minfreq, maxfreq)
        out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

        freq += bandwidth

    if freq < 20000:
        minfreq = wavetables.to_window(freq)
        maxfreq = wavetables.to_window(20000)
        band = _extract_band(snd.frames, band, minfreq, maxfreq)
        out += [ SoundBuffer(band.copy(), channels=channels, samplerate=snd.samplerate) ]

    return out
