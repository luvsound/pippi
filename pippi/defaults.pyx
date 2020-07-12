#cython: language_level=3

cdef int DEFAULT_CHANNELS = 2
cdef int DEFAULT_SAMPLERATE = 44100
cdef unicode DEFAULT_SOUNDFILE = u'wav'
cdef int DEFAULT_WTSIZE = 4096
cdef double MIN_PULSEWIDTH = 0.001
cdef double MIN_FLOAT = 4.9406564584124654e-324
