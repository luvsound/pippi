#cython: language_level=3

from pippi cimport interpolation
from pippi.interpolation cimport BLIData

cdef double[:] _adsr(int framelength, int attack, int decay, double sustain, int release)
cdef double[:] _drink(double[:] wt, double width, double minval, double maxval)
cdef double[:] _fir(double[:] data, double[:] impulse, bint norm=*)
cdef double _mag(double[:] data)
cdef double[:] _normalize(double[:] data, double ceiling)
cdef double[:] _wavetable(int, int)
cdef double[:] _window(int, int)

cdef class Wavetable:
    cdef public double[:] data
    cdef public double lowvalue
    cdef public double highvalue
    cdef public int length
    cdef BLIData* bl_data

    cpdef Wavetable clip(Wavetable self, double minval=*, double maxval=*)
    cpdef Wavetable cut(Wavetable self, int start, int length)
    cpdef Wavetable rcut(Wavetable self, int length)
    cpdef Wavetable convolve(Wavetable self, object impulse, bint norm=*)
    cpdef void drink(Wavetable self, double width=*, object minval=*, object maxval=*)
    cpdef Wavetable harmonics(Wavetable self, object harmonics=*, object weights=*)
    cpdef Wavetable env(Wavetable self, str window_type=*)
    cpdef double max(Wavetable self)

    cdef double[:] _pad(Wavetable self, object value=*, object length=*, object mult=*)
    cdef double[:] _leftpad(Wavetable self, object value=*, int length=*, double mult=*)
    cdef double[:] _rightpad(Wavetable self, object value=*, int length=*, double mult=*)
    cpdef void leftpad(Wavetable self, object value=*, int length=*, double mult=*)
    cpdef Wavetable leftpadded(Wavetable self, object value=*, int length=*, double mult=*)
    cpdef void rightpad(Wavetable self, object value=*, int length=*, double mult=*)
    cpdef Wavetable rightpadded(Wavetable self, object value=*, int length=*, double mult=*)
    cpdef void pad(Wavetable self, object value=*, object length=*, object mult=*)
    cpdef Wavetable padded(Wavetable self, object value=*, object length=*, object mult=*)

    cpdef void repeat(Wavetable self, int reps=*)
    cpdef Wavetable repeated(Wavetable self, int reps=*)
    cpdef void reverse(Wavetable self)
    cpdef Wavetable reversed(Wavetable self)
    cpdef Wavetable taper(Wavetable self, int length)
    cpdef void scale(Wavetable self, double fromlow=*, double fromhigh=*, double tolow=*, double tohigh=*, bint log=*)
    cpdef Wavetable scaled(Wavetable self, double fromlow=*, double fromhigh=*, double tolow=*, double tohigh=*, bint log=*)
    cpdef void snap(Wavetable self, double mult=*, object pattern=*)
    cpdef Wavetable snapped(Wavetable self, double mult=*, object pattern=*)
    cpdef void skew(Wavetable self, double tip)
    cpdef Wavetable skewed(Wavetable self, double tip)
    cpdef void normalize(Wavetable self, double amount=*)
    cpdef void crush(Wavetable self, int steps)
    cpdef Wavetable crushed(Wavetable self, int steps)
    cpdef double interp(Wavetable self, double pos, str method=*)
    cpdef list toonsets(Wavetable self, double length=*)

    cpdef void bli_init(Wavetable self, int quality)
    cpdef double bli_pos(Wavetable self, double pos, double inc)

    cpdef void write(Wavetable self, object path=*, int samplerate=*)

cdef int SINE
cdef int SINEIN 
cdef int SINEOUT
cdef int COS
cdef int TRI
cdef int SAW
cdef int PHASOR
cdef int RSAW
cdef int HANN
cdef int HANNIN
cdef int HANNOUT
cdef int HAMM
cdef int BLACK
cdef int BLACKMAN
cdef int BART
cdef int BARTLETT
cdef int KAISER
cdef int SQUARE
cdef int RND
cdef int LINEAR
cdef int LINE
cdef int TRUNC
cdef int HERMITE
cdef int CONSTANT
cdef int GOGINS
cdef int SINC
cdef int GAUSS
cdef int GAUSSIN
cdef int GAUSSOUT

cdef int LP
cdef int HP
cdef int BP

cdef int LEN_WINDOWS
cdef int* ALL_WINDOWS
cdef int LEN_WAVETABLES
cdef int* ALL_WAVETABLES

cpdef double[:] to_window(object w, int wtsize=?)
cpdef double[:] to_wavetable(object w, int wtsize=?)
cpdef list to_stack(list wavetables, int wtsize=?)
cdef int to_flag(str value)
cpdef Wavetable _randline(int numpoints, double lowvalue=?, double highvalue=?, int wtsize=?)
cdef double[:] _window(int window_type, int length)
cdef double[:] _adsr(int framelength, int attack, int decay, double sustain, int release)
cpdef double[:] adsr(int length, int attack, int decay, double sustain, int release)
cdef double[:] _wavetable(int wavetable_type, int length)
cpdef double[:] wavetable(int wavetable_type, int length, double[:] data=?)
cdef double[:] _seesaw(double[:] wt, int length, double tip=*)
cpdef Wavetable seesaw(object wt, int length, double tip=*)
