cdef struct Scale:
    int* principle_tones
    int octave
    int semitones
    int interval
    int steps
    bint interpolation
    bint infrapolation
    bint ultrapolation


cdef int[:] _principle_tones(int interval, int octave)
cpdef list principle_tones(int interval, int octave=*)
