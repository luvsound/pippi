#cython: language_level=3

from pippi cimport interpolation
from libc.stdlib cimport malloc, free
import numpy as np

cdef double** memoryview2ftbls(double[:,:] snd):
    cdef int length = snd.shape[0]
    cdef int channels = snd.shape[1]
    cdef int i = 0
    cdef int c = 0
    cdef double** tbls = <double**>malloc(channels * sizeof(double*))
    cdef double* tbl

    for c in range(channels):
        tbl = <double*>malloc(length * sizeof(double))
        for i in range(length):
            tbl[i] = <double>snd[i,c]
        tbls[c] = tbl

    return tbls

cdef double[:,:] _bitcrush(double[:,:] snd, double[:,:] out, double bitdepth, double samplerate, int length, int channels):
    cdef sp_data* sp
    cdef sp_bitcrush* bitcrush
    cdef double sample = 0
    cdef double crushed = 0
    cdef int i=0, c=0

    sp_create(&sp)

    for c in range(channels):
        sp_bitcrush_create(&bitcrush)
        sp_bitcrush_init(sp, bitcrush)
        bitcrush.bitdepth = bitdepth
        bitcrush.srate = samplerate

        for i in range(length):
            sp_bitcrush_compute(sp, bitcrush, &snd[i,c], &crushed)
            out[i,c] = crushed

        sp_bitcrush_destroy(&bitcrush)

    sp_destroy(&sp)

    return out

cpdef double[:,:] bitcrush(double[:,:] snd, double bitdepth, double samplerate):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _bitcrush(snd, out, bitdepth, samplerate, length, channels)

cdef double[:,:] _butbp(double[:,:] snd, double[:,:] out, double[:] freq, int length, int channels):
    cdef sp_data* sp
    cdef sp_butbp* butbp
    cdef sp_bal* bal 
    cdef double sample = 0
    cdef double filtered = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0
    cdef double pos = 0

    sp_create(&sp)

    for c in range(channels):
        sp_bal_create(&bal)
        sp_bal_init(sp, bal)
        sp_butbp_create(&butbp)
        sp_butbp_init(sp, butbp)

        pos = 0
        for i in range(length):
            pos = <double>i / <double>length
            butbp.freq = interpolation._linear_pos(freq, pos)
            sample = <double>snd[i,c]
            sp_butbp_compute(sp, butbp, &sample, &filtered)
            sp_bal_compute(sp, bal, &filtered, &sample, &output)
            out[i,c] = <double>output

        sp_butbp_destroy(&butbp)
        sp_bal_destroy(&bal)

    sp_destroy(&sp)

    return out

cpdef double[:,:] butbp(double[:,:] snd, double[:] freq):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _butbp(snd, out, freq, length, channels)

cdef double[:,:] _butbr(double[:,:] snd, double[:,:] out, double[:] freq, int length, int channels):
    cdef sp_data* sp
    cdef sp_butbr* butbr
    cdef sp_bal* bal 
    cdef double sample = 0
    cdef double filtered = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0
    cdef double pos = 0

    sp_create(&sp)

    for c in range(channels):
        sp_bal_create(&bal)
        sp_bal_init(sp, bal)
        sp_butbr_create(&butbr)
        sp_butbr_init(sp, butbr)

        for i in range(length):
            pos = <double>i / <double>length
            butbr.freq = interpolation._linear_pos(freq, pos)
            sample = <double>snd[i,c]
            sp_butbr_compute(sp, butbr, &sample, &filtered)
            sp_bal_compute(sp, bal, &filtered, &sample, &output)
            out[i,c] = <double>output

        sp_butbr_destroy(&butbr)
        sp_bal_destroy(&bal)

    sp_destroy(&sp)

    return out

cpdef double[:,:] butbr(double[:,:] snd, double[:] freq):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _butbr(snd, out, freq, length, channels)

cdef double[:,:] _buthp(double[:,:] snd, double[:,:] out, double[:] freq, int length, int channels):
    cdef sp_data* sp
    cdef sp_buthp* buthp
    cdef sp_bal* bal 
    cdef double sample = 0
    cdef double filtered = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0
    cdef double pos = 0

    sp_create(&sp)

    for c in range(channels):
        sp_bal_create(&bal)
        sp_bal_init(sp, bal)
        sp_buthp_create(&buthp)
        sp_buthp_init(sp, buthp)

        for i in range(length):
            pos = <double>i / <double>length
            buthp.freq = interpolation._linear_pos(freq, pos)
            sample = <double>snd[i,c]
            sp_buthp_compute(sp, buthp, &sample, &filtered)
            sp_bal_compute(sp, bal, &filtered, &sample, &output)
            out[i,c] = <double>output

        sp_buthp_destroy(&buthp)
        sp_bal_destroy(&bal)

    sp_destroy(&sp)

    return out

cpdef double[:,:] buthp(double[:,:] snd, double[:] freq):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _buthp(snd, out, freq, length, channels)

cdef double[:,:] _butlp(double[:,:] snd, double[:,:] out, double[:] freq, int length, int channels):
    cdef sp_data* sp
    cdef sp_butlp* butlp
    cdef sp_bal* bal 
    cdef double sample = 0
    cdef double filtered = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0
    cdef double pos = 0

    sp_create(&sp)

    for c in range(channels):
        sp_bal_create(&bal)
        sp_bal_init(sp, bal)
        sp_butlp_create(&butlp)
        sp_butlp_init(sp, butlp)

        for i in range(length):
            pos = <double>i / <double>length
            butlp.freq = interpolation._linear_pos(freq, pos)
            sample = <double>snd[i,c]
            sp_butlp_compute(sp, butlp, &sample, &filtered)
            sp_bal_compute(sp, bal, &filtered, &sample, &output)
            out[i,c] = <double>output

        sp_butlp_destroy(&butlp)
        sp_bal_destroy(&bal)

    sp_destroy(&sp)

    return out

cpdef double[:,:] butlp(double[:,:] snd, double[:] freq):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _butlp(snd, out, freq, length, channels)

cdef double[:,:] _compressor(double[:,:] snd, double[:,:] out, double ratio, double thresh, double atk, double rel, int length, int channels):
    cdef sp_data* sp
    cdef sp_compressor* compressor
    cdef double sample = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0

    sp_create(&sp)

    for c in range(channels):
        sp_compressor_create(&compressor)
        sp_compressor_init(sp, compressor)

        compressor.ratio = &ratio
        compressor.thresh = &thresh
        compressor.atk = &atk
        compressor.rel = &rel

        for i in range(length):
            sample = <double>snd[i,c]
            sp_compressor_compute(sp, compressor, &sample, &output)
            out[i,c] = <double>output

        sp_compressor_destroy(&compressor)

    sp_destroy(&sp)

    return out

cpdef double[:,:] compressor(double[:,:] snd, double ratio, double thresh, double atk, double rel):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _compressor(snd, out, ratio, thresh, atk, rel, length, channels)

cdef double[:,:] _dcblock(double[:,:] snd, double[:,:] out, int length, int channels):
    cdef sp_data* sp
    cdef sp_dcblock* dcblock
    cdef double sample = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0

    sp_create(&sp)

    for c in range(channels):
        sp_dcblock_create(&dcblock)
        sp_dcblock_init(sp, dcblock)

        for i in range(length):
            sample = <double>snd[i,c]
            sp_dcblock_compute(sp, dcblock, &sample, &output)
            out[i,c] = <double>output

        sp_dcblock_destroy(&dcblock)

    sp_destroy(&sp)

    return out

cpdef double[:,:] dcblock(double[:,:] snd):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _dcblock(snd.frames, out, length, channels)

cdef double[:,:] _mincer(double[:,:] snd, 
                         double[:,:] out, 
                         double sndlength, 
                         int sndframelength, 
                         int wtsize, 
                         int length, 
                         int channels, 
                         double[:] time, 
                         double amp, 
                         double[:] pitch):
    cdef sp_data* sp
    cdef sp_mincer* mincer
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0
    cdef double** tbls = memoryview2ftbls(snd)
    cdef double pos = 0
    cdef sp_ftbl* tbl

    sp_create(&sp)

    for c in range(channels):
        sp_ftbl_bind(sp, &tbl, tbls[c], sndframelength)
        sp_mincer_create(&mincer)
        sp_mincer_init(sp, mincer, tbl, wtsize)

        mincer.amp = amp

        for i in range(length):
            pos = <double>i/<double>length
            mincer.time = <double>interpolation._linear_pos(time, pos) * sndlength
            mincer.pitch = <double>interpolation._linear_pos(pitch, pos)
            sp_mincer_compute(sp, mincer, NULL, &output)
            out[i,c] = <double>output

        sp_mincer_destroy(&mincer)
        sp_ftbl_destroy(&tbl)
        free(tbls[c])

    sp_destroy(&sp)
    free(tbls)

    return out

cpdef double[:,:] mincer(double[:,:] snd, double length, double[:] time, double amp, double[:] pitch, int wtsize=4096, int samplerate=44100):
    cdef int framelength = <int>(samplerate * length)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((framelength, channels), dtype='d')
    return _mincer(snd, out, length, <int>len(snd), wtsize, framelength, channels, time, amp, pitch)

cdef double[:,:] _saturator(double[:,:] snd, double[:,:] out, double drive, double dcoffset, int length, int channels, bint dcblock):
    cdef sp_data* sp
    cdef sp_saturator* saturator
    cdef sp_dcblock* dcblocker
    cdef double sample = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0

    sp_create(&sp)

    for c in range(channels):
        sp_saturator_create(&saturator)
        sp_saturator_init(sp, saturator)

        saturator.drive = drive
        saturator.dcoffset = dcoffset

        sp_dcblock_create(&dcblocker)
        sp_dcblock_init(sp, dcblocker)

        for i in range(length):
            sample = <double>snd[i,c]
            sp_saturator_compute(sp, saturator, &sample, &output)
            sp_dcblock_compute(sp, dcblocker, &sample, &output)
            out[i,c] = <double>output

        sp_saturator_destroy(&saturator)
        sp_dcblock_destroy(&dcblocker)

    sp_destroy(&sp)

    return out

cpdef double[:,:] saturator(double[:,:] snd, double drive, double dcoffset, bint dcblock):
    cdef int length = <int>len(snd)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    return _saturator(snd, out, drive, dcoffset, length, channels, dcblock)

cdef double[:,:] _paulstretch(double[:,:] snd, double[:,:] out, double windowsize, double stretch, int length, int outlength, int channels):
    cdef sp_data* sp
    cdef sp_paulstretch* paulstretch
    cdef double sample = 0
    cdef double output = 0
    cdef int i = 0
    cdef int c = 0
    cdef double** tbls = memoryview2ftbls(snd)
    cdef sp_ftbl* tbl

    sp_create(&sp)
    
    for c in range(channels):
        sp_ftbl_bind(sp, &tbl, tbls[c], length)
        sp_paulstretch_create(&paulstretch)
        sp_paulstretch_init(sp, paulstretch, tbl, windowsize, stretch)

        for i in range(outlength):
            sp_paulstretch_compute(sp, paulstretch, NULL, &output)
            out[i,c] = <double>output

        sp_paulstretch_destroy(&paulstretch)
        sp_ftbl_destroy(&tbl)
        free(tbls[c])

    sp_destroy(&sp)
    free(tbls)

    return out

cpdef double[:,:] paulstretch(double[:,:] snd, double windowsize, double stretch, int samplerate=44100):
    cdef int length = <int>len(snd)
    cdef int outlength = <int>(stretch * samplerate)
    cdef int channels = <int>snd.shape[1]
    cdef double[:,:] out = np.zeros((outlength, channels), dtype='d')
    return _paulstretch(snd, out, windowsize, stretch, length, outlength, channels)

cdef double[:,:] _bar(double[:,:] out, int length, double[:] amp, double stiffness, double decay, double leftclamp, double rightclamp, double scan, double barpos, double velocity, double width, double loss, int channels):
    cdef sp_data* sp
    cdef sp_bar* bar
    cdef int i=0, c=0
    cdef double t=1, output=0, pos=0, a=1

    sp_create(&sp)

    for c in range(channels):
        sp_bar_create(&bar)
        sp_bar_init(sp, bar, stiffness, loss)
        bar.T30 = decay
        bar.bcL = leftclamp
        bar.bcR = rightclamp
        bar.scan = scan
        bar.pos = barpos
        bar.vel = velocity
        bar.wid = width

        for i in range(length):
            if i > 0:
                t = 0 

            sp_bar_compute(sp, bar, &t, &output)
            pos = <double>i / <double>length
            a = interpolation._linear_pos(amp, pos)
            out[i,c] = output * a

        sp_bar_destroy(&bar)

    sp_destroy(&sp)

    return out


