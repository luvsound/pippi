#cython: language_level=3

from libc cimport math

cpdef double mtof(double midi_note):
    return 2**((midi_note-69)/12.0) * 440

cpdef double ftom(double freq):
    return (math.log(freq / 440.0) / math.log(2)) * 12 + 69

cpdef int ftomi(double freq):
    return <int>(round(ftom(freq)))


