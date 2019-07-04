#cython: language_level=3

import numpy as np
cimport numpy as np
from pippi.wavetables cimport to_window
from libc cimport math

cdef double[:] _scale(double[:] out, double[:] source, double fromlow, double fromhigh, double tolow, double tohigh, bint log):
    cdef int i = 0
    cdef double v = 0
    cdef double _tolow = min(tolow, tohigh)
    cdef double _tohigh = max(tolow, tohigh)
    cdef double _fromlow = min(fromlow, fromhigh)
    cdef double _fromhigh = max(fromlow, fromhigh)

    cdef double todiff = _tohigh - _tolow
    cdef double fromdiff = _fromhigh - _fromlow

    if log:
        for i in range(len(source)):
            v = ((source[i] - _fromlow) / fromdiff)
            v = math.log(v * (math.e-1) + 1)
            out[i] = v * todiff + tolow

    else:
        for i in range(len(source)):
            out[i] = ((source[i] - _fromlow) / fromdiff) * todiff + tolow

    return out

cpdef list scale(list source, double fromlow=-1, double fromhigh=1, double tolow=0, double tohigh=1, bint log=False):
    cdef unsigned int length = len(source)
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef double[:] _source = np.array(source, dtype='d')
    return np.array(_scale(out, _source, fromlow, fromhigh, tolow, tohigh, log), dtype='d').tolist()

cdef double[:] _snap_pattern(double[:] out, double[:] source, double[:] pattern):
    cdef int i=0, j=0
    cdef double v=0, t=0

    for i in range(len(source)):
        v = source[i]
        t = pattern[0]
        for j in range(len(pattern)):
            if abs(v - pattern[j]) < abs(v - t):
                t = pattern[j]
        out[i] = t

    return out

cdef double[:] _snap_mult(double[:] out, double[:] source, double mult):
    cdef int i=0, m=1
    cdef double v = 0
    for i in range(len(source)):
        v = source[i]
        if v < mult:
            out[i] = mult
            continue
        
        while mult * m < v:
            m += 1

        out[i] = mult * m

    return out

cpdef list snap(list source, double mult=0, object pattern=None):
    if mult <= 0 and pattern is None:
        raise ValueError('Please provide a valid quantization multiple or pattern')

    cdef unsigned int length = len(source)
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef double[:] _source = np.array(source, dtype='d')

    if mult > 0:
        return np.array(_snap_mult(out, _source, mult), dtype='d').tolist()

    if pattern is None or (pattern is not None and len(pattern) == 0):
        raise ValueError('Invalid (empty) pattern')

    cdef double[:] _pattern = to_window(pattern)
    return np.array(_snap_pattern(out, _source, _pattern), dtype='d').tolist()

