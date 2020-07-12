# cython: language_level=3, cdivision=True, wraparound=False, boundscheck=False, initializedcheck=False

import numpy as np
cimport numpy as np

np.import_array()

cdef int[:] _principle_tones(int interval, int octave):
    octave = max(2, octave)
    interval = max(1, interval)
    cdef int semitones = interval

    if octave == interval:
        return np.zeros(1, dtype='i')

    while semitones % octave != 0:
        semitones += interval

    cdef int octaves = semitones // octave 
    cdef int steps = semitones // interval

    print('semitones', semitones, 'octaves', octaves, 'steps', steps, 'interval', interval)

    cdef int step = 0
    cdef int[:] scale = np.zeros(steps, dtype='i')
    for step in range(steps):
        scale[step] = step * interval

    return scale

cpdef list principle_tones(int interval, int octave=12):
    cdef int step = 0
    return [ step for step in _principle_tones(interval, octave) ]
