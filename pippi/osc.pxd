#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer
from pippi.interpolation cimport BLIData

ctypedef double (*osc_interp_point_t)(double[:] data, double point, BLIData* bl_data) nogil

cdef class Osc:
    cdef public double[:] freq
    cdef public double[:] amp
    cdef public double[:] wavetable
    cdef public double[:] pm

    cdef double freq_phase
    cdef double amp_phase
    cdef double wt_phase
    cdef double pm_phase

    cdef public int channels
    cdef public int samplerate
    cdef public int wtsize

    cdef BLIData* bl_data

    cdef osc_interp_point_t interp_method

    cdef SoundBuffer _play(self, int length)
