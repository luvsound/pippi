#cython: language_level=3

from pippi.breakpoints cimport Breakpoint
from pippi.interpolation cimport interp_point_t

cdef class DSS:
    cdef public double[:] freq
    cdef public double[:] xwidth
    cdef public double[:] ywidth
    cdef public double[:] amp
    cdef public double[:] wavetable
    cdef public double[:] fwidth
    cdef public double[:] awidth
    cdef public double[:] fbound
    cdef public double[:] abound

    cdef public Breakpoint points

    cdef interp_point_t freq_interpolator

    cdef double freq_phase
    cdef double xwidth_phase
    cdef double ywidth_phase
    cdef double amp_phase
    cdef double wt_phase
    cdef double fwidth_phase
    cdef double awidth_phase
    cdef double fbound_phase
    cdef double abound_phase

    cdef public int channels
    cdef public int samplerate
    cdef public int numpoints
    cdef public int wtsize

    cdef object _play(self, int length)

