#cython: language_level=3

import collections
import numbers

cimport cython
import soundfile
cimport numpy as np
import numpy as np
import re

from cpython.array cimport array, clone

from libc.stdlib cimport malloc, realloc, calloc, free
from libc cimport math

from pippi.defaults cimport DEFAULT_SAMPLERATE, DEFAULT_WTSIZE, PI
from pippi cimport interpolation
from pippi cimport rand
from pippi import graph
from pippi.soundbuffer cimport SoundBuffer
from pippi.lists cimport _scale, _scaleinplace, _snap_mult, _snap_pattern

cdef int SINE = 0
cdef int SINEIN = 17
cdef int SINEOUT = 18
cdef int COS = 1
cdef int TRI = 2
cdef int SAW = 3
cdef int RSAW = 4
cdef int HANN = 5
cdef int HANNIN = 21
cdef int HANNOUT = 22
cdef int HAMM = 6
cdef int BLACK = 7
cdef int BLACKMAN = 7
cdef int BART = 8
cdef int BARTLETT = 8
cdef int KAISER = 9
cdef int SQUARE = 10
cdef int RND = 11
cdef int LINE = SAW
cdef int PHASOR = SAW
cdef int SINC = 23
cdef int GAUSS = 24
cdef int GAUSSIN = 25
cdef int GAUSSOUT = 26
cdef int PLUCKIN = 27
cdef int PLUCKOUT = 28

cdef int LINEAR = 12
cdef int TRUNC = 13
cdef int HERMITE = 14
cdef int CONSTANT = 15
cdef int GOGINS = 16

cdef int HP = 29
cdef int LP = 30
cdef int BP = 31

cdef int LEN_WINDOWS = 17
cdef int* ALL_WINDOWS = [
            SINE, 
            SINEIN, 
            SINEOUT, 
            COS,
            TRI, 
            SAW,
            RSAW,
            HANN,
            HANNIN,
            HANNOUT,
            HAMM,
            BLACK,
            BART,
            KAISER,
            GAUSS,
            GAUSSIN,
            GAUSSOUT,
            PLUCKIN,
            PLUCKOUT,
        ]

cdef int LEN_WAVETABLES = 6
cdef int* ALL_WAVETABLES = [
            SINE, 
            COS,
            TRI,
            SAW,
            RSAW,
            SQUARE
        ]

cdef double SQUARE_DUTY = 0.5

SEGMENT_RE = re.compile('(?P<length>0?\.?\d+)?,?(?P<wtype>\w+),?(?P<start>0?\.?\d+)?-?(?P<end>0?\.?\d+)?')

cdef int to_flag(str value):
    cdef dict flags = {
        'sine': SINE, 
        'sinein': SINEIN, 
        'sineout': SINEOUT, 
        'cos': COS, 
        'tri': TRI, 
        'saw': SAW, 
        'phasor': PHASOR, 
        'rsaw': RSAW, 
        'hann': HANN, 
        'hamm': HAMM, 
        'black': BLACK, 
        'blackman': BLACKMAN, 
        'bart': BART, 
        'bartlett': BARTLETT, 
        'kaiser': KAISER, 
        'rnd': RND, 
        'line': LINE, 
        'hannin': HANNIN, 
        'hannout': HANNOUT, 
        'square': SQUARE, 
        'linear': LINEAR, 
        'trunc': TRUNC, 
        'hermite': HERMITE, 
        'constant': CONSTANT, 
        'gogins': GOGINS, 
        'sinc': SINC,
        'gauss': GAUSS,
        'gaussin': GAUSSIN,
        'gaussout': GAUSSOUT,
        'pluckin': PLUCKIN,
        'pluckout': PLUCKOUT,
        'lp': LP,
        'hp': HP,
        'bp': BP,
    }

    return flags[value]

@cython.boundscheck(False)
@cython.wraparound(False)
cdef double[:] _imul1d(double[:] output, double[:] values):
    cdef int i = 0
    cdef int framelength = len(output)

    if <int>len(values) != framelength:
        values = interpolation._linear(values, framelength)

    for i in range(framelength):
        output[i] *= values[i]

    return output

@cython.boundscheck(False)
@cython.wraparound(False)
cdef double[:] _mul1d(double[:] output, double[:] values):
    cdef int i = 0
    cdef int framelength = len(output)
    cdef double[:] out = np.zeros(framelength, dtype='d')

    if <int>len(values) != framelength:
        values = interpolation._linear(values, framelength)

    for i in range(framelength):
        out[i] = output[i] * values[i]

    return out

cdef double[:] _drink(double[:] wt, double width, double minval, double maxval):
    cdef int i = 0
    cdef int wlength = len(wt)-2

    for i in range(wlength):
        wt[i+1] = max(minval, min(wt[i+1] + rand.rand(-width, width), maxval))
    
    return wt

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _gaussian(int length):
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef int i=0
    cdef double ax=0, nn=0

    nn = 0.5 * (length-1)
    for i in range(length):
        ax = (i-nn) / 0.3 / nn
        out[i] = math.exp(-0.5 * ax * ax)

    return out

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _gaussian_in(int length):
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef int i=0
    cdef double ax=0

    for i in range(length):
        ax = (<double>(length-i) / <double>length) * 4.0
        out[i] = math.exp(-0.5 * ax * ax)

    return out

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _gaussian_out(int length):
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef int i=0
    cdef double ax=0

    for i in range(length):
        ax = (<double>i / <double>length) * 4.0
        out[i] = math.exp(-0.5 * ax * ax)

    return out

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _pluck_in(int length):
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef double[:] mul = np.zeros(length, dtype='d')
    cdef int i=0

    out = _window(HANNIN, length)
    out = _seesaw(out, length, rand.rand(0.97, 0.99))
    mul = _window(HANNIN, length)

    for i in range(length):
        out[i] = out[i] * out[i] * mul[i]

    return out

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _pluck_out(int length):
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef double[:] mul = np.zeros(length, dtype='d')
    cdef int i=0

    out = _window(HANNOUT, length)
    out = _seesaw(out, length, rand.rand(0.01, 0.03))
    mul = _window(HANNOUT, length)

    for i in range(length):
        out[i] = out[i] * out[i] * mul[i]

    return out

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _fir(double[:] data, double[:] impulse, bint norm=True):
    cdef int datlength = len(data)
    cdef int implength = len(impulse)
    cdef int outlength = datlength + implength - 1
    cdef double[:] out = np.zeros(outlength, dtype='d')
    cdef double maxval = 1
    cdef int i=0, j=0

    if norm:
        maxval = _mag(data)

    for i in range(datlength):
        for j in range(implength):
            out[i+j] += data[i] * impulse[j]

    if norm:
        return _normalize(out, maxval)
    else:
        return out

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double _mag(double[:] data):
    cdef int i = 0
    cdef int framelength = len(data)
    cdef double maxval = 0

    for i in range(framelength):
        maxval = max(maxval, abs(data[i]))

    return maxval

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:] _normalize(double[:] data, double ceiling):
    cdef int i = 0
    cdef int framelength = len(data)
    cdef int channels = data.shape[1]
    cdef double normval = 1
    cdef double maxval = _mag(data)

    normval = ceiling / maxval
    for i in range(framelength):
        data[i] *= normval

    return data

cpdef object rebuild_wavetable(double[:] data):
    return Wavetable(data)

cdef class Wavetable:
    def __cinit__(self, object values, 
            object lowvalue=None, 
            object highvalue=None,
            int wtsize=0, 
            bint window=False):
        cdef bint scaled = False
        cdef bint resized = False

        if window:
            self.data = to_window(values, wtsize)
        else:
            self.data = to_wavetable(values, wtsize)

        if lowvalue is None:
            self.lowvalue = np.min(self.data)
        else:
            scaled = True
            self.lowvalue = <double>lowvalue

        if highvalue is None:
            self.highvalue = np.max(self.data)
        else:
            scaled = True
            self.highvalue = <double>highvalue

        self.length = len(self.data)

        if scaled:
            self.data = _scaleinplace(self.data, np.min(self.data), np.max(self.data), self.lowvalue, self.highvalue, False)

    def __reduce__(self):
        return (rebuild_wavetable, (np.asarray(self.data),))

    ##################################
    # (+) Concatenation operator (+) #
    ##################################
    def __add__(self, value):
        cdef double[:] out

        if not isinstance(self, Wavetable):
            return NotImplemented

        if isinstance(value, numbers.Real):
            out = np.append(self.data, value)
        elif isinstance(value, Wavetable):
            out = np.hstack((self.data, value.data))
        else:
            try:
                out = np.hstack((self.data, np.array(value).flatten()))
            except TypeError as e:
                return NotImplemented

        return Wavetable(out)

    def __iadd__(self, value):
        if isinstance(value, numbers.Real):
            self.data = np.append(self.data, value)
        elif isinstance(value, Wavetable):
            self.data = np.hstack(self.data, value.data)
        else:
            try:
                self.data = np.hstack((self.data, np.array(value).flatten()))
            except TypeError as e:
                return NotImplemented

        return self

    def __radd__(self, value):
        if isinstance(value, numbers.Real):
            return Wavetable(np.append(value, self.data))
        return self + value


    ########################
    # (&) Mix operator (&) #
    ########################
    def __and__(self, value):
        cdef double[:] out
        cdef double[:] val

        if not isinstance(self, Wavetable):
            return NotImplemented

        if isinstance(value, numbers.Real):
            out = np.add(self.data, value)
            return Wavetable(out)

        elif isinstance(value, Wavetable):
            val = value.data
        else:
            try:
                val = np.array(value).flatten()
            except TypeError as e:
                return NotImplemented

        if <int>len(val) != len(self.data):
            val = interpolation._linear(val, len(self.data))

        out = np.add(self.data, val)

        return Wavetable(out)

    def __iand__(self, value):
        cdef double[:] val

        if isinstance(value, numbers.Real):
            self.data = np.add(self.data, value)
            return self

        elif isinstance(value, Wavetable):
            val = value.data
        else:
            try:
                val = np.array(value).flatten()
            except TypeError as e:
                return NotImplemented

        if <int>len(val) != len(self.data):
            val = interpolation._linear(val, len(self.data))

        self.data = np.add(self.data, val)

        return self

    def __rand__(self, value):
        return self & value


    ##############
    # Truthiness #
    ##############
    def __bool__(self):
        return bool(len(self))

    def __getitem__(self, position):
        if isinstance(position, int):
            return self.data[<int>position]
        return Wavetable(self.data[position])

    def __len__(self):
        return 0 if self.data is None else len(self.data)

    def __eq__(self, other):
        try:
            return len(self) == len(other) and all(a == b for a, b in zip(self, other))
        except TypeError as e:
            return NotImplemented


    ###################################
    # (*) Multiplication operator (*) #
    ###################################
    def __mul__(self, value):
        cdef double[:] out

        if not isinstance(self, Wavetable):
            return NotImplemented

        if isinstance(value, numbers.Real):
            out = np.multiply(self.data, value)
        elif isinstance(value, Wavetable):
            out = _mul1d(self.data, value.data)
        elif isinstance(value, list):
            out = _mul1d(self.data, np.array(value, dtype='d'))
        else:
            try:
                out = _mul1d(self.data, np.array(value, dtype='d'))
            except TypeError:
                return NotImplemented

        return Wavetable(out)

    def __imul__(self, value):
        if isinstance(value, numbers.Real):
            self.data = np.multiply(self.data, value)
        elif isinstance(value, Wavetable):
            self.data = _imul1d(self.data, value.data)
        elif isinstance(value, list):
            self.data = _imul1d(self.data, np.array(value, dtype='d'))
        else:
            try:
                self.data = _imul1d(self.data, np.array(value, dtype='d'))
            except TypeError:
                return NotImplemented

        return self

    def __rmul__(self, value):
        return self * value


    ################################
    # (-) Subtraction operator (-) #
    ################################
    def __sub__(self, value):
        cdef double[:] out
        cdef double[:] val

        if not isinstance(self, Wavetable):
            return NotImplemented

        if isinstance(value, numbers.Real):
            out = np.subtract(self.data, value)
            return Wavetable(out)
        elif isinstance(value, Wavetable):
            val = value.data
        else:
            try:
                val = np.array(value, dtype='d')
            except TypeError as e:
                return NotImplemented

        if <int>len(val) != len(self.data):
            val = interpolation._linear(val, len(self.data))

        out = np.subtract(self.data, val)

        return Wavetable(out)

    def __isub__(self, value):
        cdef double[:] val

        if isinstance(value, numbers.Real):
            self.data = np.subtract(self.data, value)
            return self
        elif isinstance(value, Wavetable):
            val = value.data
        else:
            try:
                val = np.array(value, dtype='d')
            except TypeError as e:
                return NotImplemented

        if <int>len(val) != len(self.data):
            val = interpolation._linear(val, len(self.data))

        self.data = np.subtract(self.data, val)

        return self

    def __rsub__(self, value):
        if isinstance(value, numbers.Real):
            # Subtracting a wavetable from a number doesn't really make any sense
            return NotImplemented
        return self - value

    def __repr__(self):
        return 'Wavetable({})'.format([ d for d in self.data])

    cpdef Wavetable clip(Wavetable self, double minval=-1, double maxval=1):
        return Wavetable(np.clip(self.data, minval, maxval))

    cpdef Wavetable cut(Wavetable self, int start, int length):
        start = min(max(0, start), len(self.data))
        length = min(max(1, length), len(self.data)-start)
        cdef double[:] out = np.zeros(length, dtype='d')
        for i in range(length):
            out[i] = self.data[i+start]
        return Wavetable(out)

    cpdef Wavetable rcut(Wavetable self, int length):
        cdef int start = rand.randint(0, len(self.data)-length)
        return self.cut(start, length)

    cpdef Wavetable convolve(Wavetable self, object impulse, bint norm=True):
        cdef double[:] _impulse = to_window(impulse)
        return Wavetable(_fir(self.data, _impulse, norm))

    cpdef void drink(Wavetable self, double width=0.1, object minval=None, object maxval=None):
        if minval is None:
            minval = np.min(self.data)

        if maxval is None:
            maxval = np.max(self.data)

        self.data = _drink(self.data, width, minval, maxval)

    cpdef Wavetable harmonics(Wavetable self, object harmonics=None, object weights=None):
        if harmonics is None:
            harmonics = [1, 2, 3]

        if weights is None:
            weights = [1, 0.5, 0.25]

        cdef int[:] _harmonics = np.array(harmonics, dtype='i')
        cdef double[:] _weights = np.array(weights, dtype='d')

        cdef double weight
        cdef int rank
        cdef int length = len(self)
        cdef int i = 0, j = 0

        cdef double harmonic_phase = 0
        cdef int harmonic_boundry = max(len(self.data)-1, 1)
        cdef double harmonic_phase_inc = (1.0/length) * harmonic_boundry
        cdef double[:] out = np.zeros(length, dtype='d')
        cdef double original_mag = _mag(self.data)

        cdef int num_partials = max(len(_harmonics), len(_weights))
        cdef int wi = 0, ri = 0

        for i in range(num_partials):
            wi = i % len(_weights)
            ri = i % len(_harmonics)
            weight = _weights[wi]
            rank = _harmonics[ri]

            harmonic_phase = 0
            for j in range(length):
                out[j] += interpolation._linear_point(self.data, harmonic_phase) * weight
                harmonic_phase += rank * harmonic_phase_inc

                while harmonic_phase >= harmonic_boundry:
                    harmonic_phase -= harmonic_boundry

        out = _normalize(out, original_mag)

        return Wavetable(out)


    cpdef Wavetable env(Wavetable self, str window_type=None):
        if window_type is None:
            window_type = 'sine'
        return self * to_window(window_type, len(self))

    def graph(Wavetable self, *args, **kwargs):
        return graph.write(self, *args, **kwargs)

    cpdef double max(Wavetable self):
        return np.amax(self.data)

    cdef double[:] _leftpad(Wavetable self, object value=None, int length=-1, double mult=-1):
        cdef int _length = len(self.data)
        cdef double _value

        if value is None:
            _value = self.data[0]
        else:
            _value = <double>value

        if mult >= 0:
            length = <int>(mult * _length)

        elif length < 0:
            length = 1

        return np.pad(self.data, (length, 0), 'constant', constant_values=(value, 0))

    cdef double[:] _rightpad(Wavetable self, object value=None, int length=-1, double mult=-1):
        cdef int _length = len(self.data)
        cdef double _value

        if value is None:
            _value = self.data[_length-1]
        else:
            _value = <double>value

        if mult >= 0:
            length = <int>(mult * _length)

        elif length < 0:
            length = 1

        return np.pad(self.data, (0, length), 'constant', constant_values=(0, value))

    cdef double[:] _pad(Wavetable self, object value=None, object length=None, object mult=None):
        cdef double left_value, right_value, left_mult, right_mult
        cdef int left_length, right_length
        cdef int _length = len(self.data)

        if value is None:
            left_value = self.data[0]
            right_value = self.data[_length-1]

        elif isinstance(value, tuple):
            if value[0] is None:
                left_value = self.data[0]
            else:
                left_value = <double>value[0]

            if value[1] is None:
                right_value = self.data[_length-1]
            else:
                right_value = <double>value[1]

        else:
            left_value = <double>value
            right_value = <double>value

        if mult is not None:
            if isinstance(mult, tuple):
                left_length = <int>(<double>mult[0] * _length)
                right_length = <int>(<double>mult[1] * _length)
            else:
                left_length = <int>(<double>mult * _length)
                right_length = <int>(<double>mult * _length)

        else:
            if length is None:
                left_length = 1
                right_length = 1

            elif isinstance(length, tuple):
                left_length, right_length = length
            else:
                left_length = length
                right_length = length

        return np.pad(self.data, (left_length, right_length), 'constant', constant_values=(left_value, right_value))

    cpdef void leftpad(Wavetable self, object value=None, int length=-1, double mult=-1):
        self.data = self._leftpad(value, length, mult)

    cpdef Wavetable leftpadded(Wavetable self, object value=None, int length=-1, double mult=-1):
        return Wavetable(self._leftpad(value, length, mult))

    cpdef void rightpad(Wavetable self, object value=None, int length=-1, double mult=-1):
        self.data = self._rightpad(value, length, mult)

    cpdef Wavetable rightpadded(Wavetable self, object value=None, int length=-1, double mult=-1):
        return Wavetable(self._rightpad(value, length, mult))

    cpdef void pad(Wavetable self, object value=None, object length=None, object mult=None):
        self.data = self._pad(value, length, mult)

    cpdef Wavetable padded(Wavetable self, object value=None, object length=None, object mult=None):
        return Wavetable(self._pad(value, length, mult))

    cpdef void repeat(Wavetable self, int reps=2):
        if reps > 1:
            self.data = np.tile(self.data, reps)

    cpdef Wavetable repeated(Wavetable self, int reps=2):
        if reps <= 1:
            return self
        return Wavetable(np.tile(self.data, reps))

    cpdef void reverse(Wavetable self):
        self.data = np.flip(self.data, 0)

    cpdef Wavetable reversed(Wavetable self):
        return Wavetable(np.flip(self.data, 0))

    cpdef Wavetable taper(Wavetable self, int length):
        return self * _adsr(len(self), length, 0, 1, length)

    cpdef void scale(Wavetable self, double fromlow=-1, double fromhigh=1, double tolow=0, double tohigh=1, bint log=False):
        self.data = _scale(self.data, self.data, fromlow, fromhigh, tolow, tohigh, log)

    cpdef Wavetable scaled(Wavetable self, double fromlow=-1, double fromhigh=1, double tolow=0, double tohigh=1, bint log=False):
        cdef double[:] out = np.zeros(len(self.data), dtype='d')
        return Wavetable(_scale(out, self.data, fromlow, fromhigh, tolow, tohigh, log))

    cpdef void snap(Wavetable self, double mult=0, object pattern=None):
        if mult <= 0 and pattern is None:
            raise ValueError('Please provide a valid quantization multiple or pattern')

        cdef unsigned int length = len(self.data)
        cdef double[:] out = np.zeros(length, dtype='d')

        if mult > 0:
            self.data = _snap_mult(out, self.data, mult)
            return

        if pattern is None or (pattern is not None and len(pattern) == 0):
            raise ValueError('Invalid (empty) pattern')

        cdef double[:] _pattern = to_window(pattern)
        self.data = _snap_pattern(out, self.data, _pattern)

    cpdef Wavetable snapped(Wavetable self, double mult=0, object pattern=None):
        if mult <= 0 and pattern is None:
            raise ValueError('Please provide a valid quantization multiple or pattern')

        cdef unsigned int length = len(self.data)
        cdef double[:] out = np.zeros(length, dtype='d')

        if mult > 0:
            return Wavetable(_snap_mult(out, self.data, mult))

        if pattern is None or (pattern is not None and len(pattern) == 0):
            raise ValueError('Invalid (empty) pattern')

        cdef double[:] _pattern = to_window(pattern)
        return Wavetable(_snap_pattern(out, self.data, _pattern))

    cpdef void skew(Wavetable self, double tip):
        self.data = _seesaw(self.data, len(self.data), tip)

    cpdef Wavetable skewed(Wavetable self, double tip):
        return Wavetable(_seesaw(self.data, len(self.data), tip))

    cpdef void normalize(Wavetable self, double amount=1):
        self.data = _normalize(self.data, amount)

    cpdef void crush(Wavetable self, int steps):
        cdef double[:] out = interpolation._linear(self.data, steps)
        self.data = interpolation._trunc(out, <int>len(self))

    cpdef Wavetable crushed(Wavetable self, int steps):
        cdef double[:] out = np.zeros(len(self), dtype='d')
        out = interpolation._linear(self.data, steps)
        out = interpolation._trunc(out, len(self))
        return Wavetable(out)

    cpdef double interp(Wavetable self, double pos, str method=None):
        if method is None:
            method = 'linear'

        cdef int _method = to_flag(method)
        if _method == LINEAR:
            return interpolation._linear_pos(self.data, pos)
        elif _method == TRUNC:
            return interpolation._trunc_pos(self.data, pos)
        elif _method == HERMITE:
            return interpolation._hermite_pos(self.data, pos)
        else:
            raise ValueError('%s is not a valid interpolation method' % method)

    cpdef list toonsets(Wavetable self, double length=10):
        cdef list out = []
        cdef double pos = 0
        cdef double elapsed = 0

        while elapsed < length:
            pos = elapsed / length
            o = self.interp(pos)
            out += [ o + elapsed ]
            elapsed += o

        return out

    cpdef void write(Wavetable self, object path=None, int samplerate=DEFAULT_SAMPLERATE):
        if path is None:
            path = 'wavetable.wav'
        soundfile.write(path, self.data, samplerate)


cdef tuple _parse_polyseg(str score, int length, int wtlength):
    """ score = '1,tri .5,sine,0-.5 sine!.25 tri,.1-.2!.5'
    """    
    cdef list segments = [] 
    cdef str segment
    cdef str param
    cdef int count = 0
    cdef int segment_wtype
    cdef double segment_slew = 0
    cdef double segment_start = 0
    cdef double segment_end = 1
    cdef int segment_length = wtlength
    cdef int total_segment_length = 0

    for segment in score.split(' '):
        segment_start = 0
        segment_end = 1
        segment_slew = 0
        segment_wtype = SINE
        segment_length = wtlength

        match = SEGMENT_RE.match(segment)
        
        length = match.group('length')
        if length is not None:
            segment_length = <int>(wtlength * float(length))

        wtype = match.group('wtype')
        if wtype is not None:
            segment_wtype = to_flag(wtype)

        start = match.group('start')
        if start is not None:
            segment_start = float(start)

        end = match.group('end')
        if end is not None:
            segment_end = float(end)

        segments += (segment_length, segment_wtype, segment_start, segment_end)
        total_segment_length += segment_length

    return segments, total_segment_length

cpdef double[:] polyseg(list segments, int length):
    """ Calculate total output segment length in frames & alloc outbuf

        loop thru segments:
            - generate segment
            - write segment into outbuf

        for each segment:
            - calc the true length of the individual segment based on segment length
            - scale the size of the tmp segment to match remainder after start/end filtering
            - produce a tmp array from the waveform type (using normal wavetable or window generator)
            - copy into outbuf

        segment crossfading?

    """
    for segment_length, segment_wtype, segment_start, segment_end in segments:
        pass

    cdef double[:] out = np.zeros(length, dtype='d')

    return out


cpdef Wavetable _randline(int numpoints, double lowvalue=0, double highvalue=1, int wtsize=4096):
    cdef double[:] points = np.array([ rand.rand(lowvalue, highvalue) for _ in range(numpoints) ], dtype='d')
    return Wavetable(points, wtsize=wtsize)

cdef double[:] _window(int window_type, int length):
    cdef double[:] wt

    if window_type == RND:
        window_type = ALL_WINDOWS[rand.randint(0, LEN_WINDOWS-1)]
        wt = _window(window_type, length)

    elif window_type == SINE:
        wt = np.sin(np.linspace(0, PI, length, dtype='d'))

    elif window_type == SINEIN:
        wt = np.sin(np.linspace(0, PI/2, length, dtype='d'))

    elif window_type == SINEOUT:
        wt = np.sin(np.linspace(PI/2, PI, length, dtype='d'))

    elif window_type == COS:
        wt = (np.cos(np.linspace(0, PI*2, length, dtype='d')) + 1) * 0.5

    elif window_type == TRI:
        wt = np.bartlett(length)

    elif window_type == SAW:
        wt = np.linspace(0, 1, length, dtype='d')

    elif window_type == RSAW:
        wt = np.linspace(1, 0, length, dtype='d')

    elif window_type == HANN:
        wt = np.hanning(length)

    elif window_type == HANNIN:
        wt = np.hanning(length * 2)[:length]

    elif window_type == HANNOUT:
        wt = np.hanning(length * 2)[length:]

    elif window_type == HAMM:
        wt = np.hamming(length)

    elif window_type == BART:
        wt = np.bartlett(length)

    elif window_type == BLACK:
        wt = np.blackman(length)

    elif window_type == KAISER:
        wt = np.kaiser(length, 14)
        
    elif window_type == SINC:
        wt = np.sinc(np.linspace(-15, 15, length, dtype='d'))

    elif window_type == GAUSS:
        wt = _gaussian(length) 

    elif window_type == GAUSSIN:
        wt = _gaussian_in(length) 

    elif window_type == GAUSSOUT:
        wt = _gaussian_out(length) 

    elif window_type == PLUCKIN:
        wt = _pluck_in(length)

    elif window_type == PLUCKOUT:
        wt = _pluck_out(length)

    else:
        wt = _window(SINE, length)

    return wt

cdef double[:] _adsr(int framelength, int attack, int decay, double sustain, int release):
    cdef int alen = attack + decay + release
    cdef double mult = 1
    if alen > framelength:
        mult = <double>framelength / <double>alen
        attack = <int>(mult * attack)
        decay = <int>(mult * decay)
        release = <int>(mult * release)

    cdef int decay_breakpoint = decay + attack
    cdef int sustain_breakpoint = framelength - release
    cdef int decay_framelength = decay_breakpoint - attack
    cdef int release_framelength = framelength - sustain_breakpoint
    cdef double[:] out = np.zeros(framelength, dtype='d')

    for i in range(framelength):
        if i <= attack and attack > 0:
            out[i] = i / <double>attack

        elif i <= decay_breakpoint and decay_breakpoint > 0:
            out[i] = (1 - ((i - attack) / <double>decay_framelength)) * (1 - sustain) + sustain
    
        elif i <= sustain_breakpoint:
            out[i] = sustain

        else:
            out[i] = (1 - ((i - sustain_breakpoint) / <double>release_framelength)) * sustain

    return out

cpdef double[:] adsr(int length, int attack, int decay, double sustain, int release):
    return _adsr(length, attack, decay, sustain, release)

cdef double[:] _wavetable(int wavetable_type, int length):
    cdef double[:] wt

    if wavetable_type == RND:
        wavetable_type = ALL_WAVETABLES[rand.randint(0, LEN_WAVETABLES-1)]
        wt = _wavetable(wavetable_type, length)

    elif wavetable_type == SINE:
        wt = np.sin(np.linspace(-np.pi, np.pi, length, dtype='d', endpoint=False))

    elif wavetable_type == COS:
        wt = np.cos(np.linspace(-np.pi, np.pi, length, dtype='d', endpoint=False))

    elif wavetable_type == TRI:
        wt = np.bartlett(length+1)[0:length] * 2 - 1

    elif wavetable_type == SAW:
        wt = np.linspace(-1, 1, length, dtype='d', endpoint=False)

    elif wavetable_type == RSAW:
        wt = np.linspace(1, -1, length, dtype='d', endpoint=False)

    elif wavetable_type == SQUARE:
        tmp = np.zeros(length, dtype='d')
        duty = int(length * SQUARE_DUTY)
        tmp[:duty] = 1
        tmp[duty:] = -1
        wt = tmp

    else:
        wt = _wavetable(SINE, length)

    return wt

cpdef double[:] wavetable(int wavetable_type, int length, double[:] data=None):
    if data is not None:
        return interpolation._linear(data, length)

    return _wavetable(wavetable_type, length)

cpdef double[:] fromfile(unicode filename, int length):
    wt, _ = soundfile.read(filename, dtype='d')
    if len(wt) == length:
        return wt

    return interpolation._linear(wt, length)

cpdef double[:] to_window(object w, int wtsize=0):
    cdef double[:] wt

    if w is None:
        return None

    if isinstance(w, str):
        if wtsize <= 0:
            wtsize = DEFAULT_WTSIZE
        wt = _window(to_flag(w), wtsize)

    elif isinstance(w, numbers.Real):
        wt = np.full(1, w, dtype='d')

    elif isinstance(w, Wavetable):
        wt = w.data

    elif isinstance(w, SoundBuffer):
        wt = np.ravel(np.array(w.remix(1).frames, dtype='d'))

    elif isinstance(w, list):
        wt = np.array(w, dtype='d')

    elif isinstance(w, np.ndarray):
        wt = w

    else:
        wt = array('d', w)

    if wtsize > 0 and len(wt) != wtsize:
        wt = interpolation._linear(wt, wtsize)

    return wt

cpdef double[:] to_wavetable(object w, int wtsize=0):
    cdef double[:] wt

    if w is None:
        return None

    if isinstance(w, str):
        if wtsize <= 0:
            wtsize = DEFAULT_WTSIZE
        wt = _wavetable(to_flag(w), wtsize)

    elif isinstance(w, numbers.Real):
        wt = np.full(1, w, dtype='d')

    elif isinstance(w, Wavetable):
        wt = w.data

    elif isinstance(w, SoundBuffer):
        wt = np.ravel(np.array(w.remix(1).frames, dtype='d'))

    elif isinstance(w, list):
        wt = np.array(w, dtype='d')

    elif isinstance(w, np.ndarray):
        wt = w

    else:
        wt = array('d', w)

    if wtsize > 0 and len(wt) != wtsize:
        wt = interpolation._linear(wt, wtsize)

    return wt

cpdef list to_stack(list wavetables, int wtsize=4096):
    cdef object wt
    return [ interpolation._linear(to_wavetable(wt, wtsize), wtsize) for wt in wavetables ]

cdef double[:] _seesaw(double[:] wt, int length, double tip=0.5):
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef int wtlength = len(wt)
    cdef int i = 0
    cdef double phase_inc = (1.0 / length) * (wtlength-1)
    cdef double warp=0, m=0, pos=0
    cdef double phase = 0
    m = 0.5 - tip

    for i in range(length):
        pos = <double>i / (length-1)
        if(pos < tip):
            warp = m * (pos / tip)
        else:
            warp = m * ((1-pos) / (1-tip))

        warp *= wtlength
        out[i] = interpolation._linear_point(wt, phase+warp) 
        phase += phase_inc

    return out

cpdef Wavetable seesaw(object win, int length, double tip=0.5):
    cdef double[:] _win = to_window(win)
    cdef double[:] out = _seesaw(_win, length, tip)
    return Wavetable(out)

