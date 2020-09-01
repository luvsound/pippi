#cython: language_level=3

import numbers
import random
import reprlib

import soundfile
import numpy as np
cimport numpy as np
cimport cython
from libc cimport math

from pippi.wavetables cimport Wavetable, CONSTANT, LINEAR, SINE, GOGINS, _window, _adsr, to_window, to_flag
from pippi.dsp cimport _mag
from pippi cimport interpolation
from pippi cimport fx
from pippi cimport fft
from pippi import graph
from pippi.defaults cimport DEFAULT_SAMPLERATE, DEFAULT_CHANNELS, DEFAULT_SOUNDFILE
from pippi cimport grains
from pippi cimport soundpipe

cdef double VSPEED_MIN = 0.0001

@cython.boundscheck(False)
@cython.wraparound(False)
cdef double[:,:] _dub(double[:,:] target, int target_length, double[:,:] todub, int todub_length, int channels, int framepos) nogil:
    cdef int i = 0
    cdef int c = 0
    for i in range(todub_length):
        for c in range(channels):
            target[framepos+i, c] += todub[i, c]

    return target

cdef double[:,:] _pan(double[:,:] out, int length, int channels, double[:] _pos, int method):
    cdef double left = 0.5
    cdef double right = 0.5
    cdef int i = 0
    cdef int channel = 0
    cdef double pos = 0
    cdef double p = 0

    if method == CONSTANT:
        for channel in range(channels):
            if channel % 2 == 0:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    left = math.sqrt(pos)
                    out[i, channel] *= left
            else:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    right = math.sqrt(1 - pos)
                    out[i, channel] *= right

    elif method == LINEAR:
        for channel in range(channels):
            if channel % 2 == 0:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    left = pos
                    out[i, channel] *= left
            else:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    right = 1 - pos
                    out[i, channel] *= right

    elif method == SINE:
        for channel in range(channels):
            if channel % 2 == 0:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    left = math.sin(pos * (math.pi / 2))
                    out[i, channel] *= left
            else:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    right = math.cos(pos * (math.pi / 2))
                    out[i, channel] *= right

    elif method == GOGINS:
        for channel in range(channels):
            if channel % 2 == 0:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    left = math.sin((pos + 0.5) * (math.pi / 2))
                    out[i, channel] *= left
            else:
                for i in range(length):
                    p = <double>i / length
                    pos = interpolation._linear_pos(_pos, p)
                    right = math.cos((pos + 0.5) * (math.pi / 2))
                    out[i, channel] *= right

    return out

cdef double[:,:] _remix(double[:,:] values, int framelength, int channels):
    if values.shape[1] == channels:
        return values

    cdef double[:,:] out = None
    cdef int i = 0

    if channels <= 1:
        return np.sum(values, 1).reshape(len(values), 1)
    elif values.shape[1] == 1:
        return np.hstack([ values for _ in range(channels) ])
    else:
        out = np.zeros((framelength, channels))
        for i in range(framelength):
            out[i] = interpolation._linear(values[i], channels)
        return out

@cython.boundscheck(False)
@cython.wraparound(False)
cdef double[:,:] _mul2d(double[:,:] output, double[:,:] values):
    return np.multiply(output, _remix(values, len(output), output.shape[1]))

@cython.boundscheck(False)
@cython.wraparound(False)
cdef double[:,:] _mul1d(double[:,:] output, double[:] values):
    cdef int channel = 0
    cdef int i = 0
    cdef int channels = output.shape[1]
    cdef int framelength = len(output)

    if <int>len(values) != framelength:
        values = interpolation._linear(values, framelength)

    for channel in range(channels):
        for i in range(framelength):
            output[i][channel] *= values[i]

    return output

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] sb_adsr(double[:,:] frames, int framelength, int channels, double samplerate, double attack, double decay, double sustain, double release) nogil:
    cdef double length = <double>(framelength / samplerate)
    sustain = min(max(0, sustain), 1)
    attack = max(0, attack)
    decay = max(0, decay)
    release = max(0, release)
    cdef int i = 0
    cdef int c = 0
    cdef double alen = attack + decay + release
    cdef double mult = 1
    if alen > length:
        mult = length / alen
        attack *= mult
        decay *= mult
        release *= mult

    cdef int attack_breakpoint = <int>(samplerate * attack)
    cdef int decay_breakpoint = <int>(samplerate * decay) + attack_breakpoint
    cdef int sustain_breakpoint = framelength - <int>(release * samplerate)
    cdef int decay_framelength = decay_breakpoint - attack_breakpoint
    cdef int release_framelength = framelength - sustain_breakpoint

    for i in range(framelength):
        for c in range(channels):
            if i <= attack_breakpoint and attack_breakpoint > 0:
                frames[i,c] = frames[i,c] * (i / <double>attack_breakpoint)

            elif i <= decay_breakpoint and decay_breakpoint > 0:
                frames[i,c] = frames[i,c] * ((1 - ((i - attack_breakpoint) / <double>decay_framelength)) * (1 - sustain) + sustain)
        
            elif i <= sustain_breakpoint:
                frames[i,c] = frames[i,c] * sustain

            else:
                release = 1 - ((i - sustain_breakpoint) / <double>release_framelength)
                frames[i,c] = frames[i,c] * release * sustain

    return frames


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double[:,:] _speed(double[:,:] frames, 
                        double[:,:] out, 
                        double[:] chan, 
                        double[:] outchan, 
                        int channels) nogil:
    cdef int c = 0
    cdef int i = 0
    cdef int framelength = len(frames)
    cdef int length = len(out)

    for c in range(channels):
        for i in range(framelength):
            chan[i] = frames[i,c]

        for i in range(length):
            outchan[i] = interpolation._linear_pos(chan, <double>i/(length-1))

        for i in range(length):
            out[i,c] = outchan[i]

    return out

@cython.final
cdef class SoundBuffer:
    """ A sequence of audio frames representing a buffer of sound.

        Data may be loaded into the SoundBuffer from these sources as keyword arguments, 
        in decending order of precedence:

        - `filename`: a unicode string relative path or a full path to load from a soundfile
        - `buf`: a memoryview compatible 2D buffer of doubles <double[:,:]>
        - `frames`: a 1D or 2D python iterable (eg a list) or a 1D numpy array/buffer

        Data loaded via the `filename` keyword can load any soundfile type supported by libsndfile,
        including old favorites like WAV, AIFF, FLAC, and OGG. But no, not MP3. (At least not yet: https://github.com/erikd/libsndfile/issues/258)
        If the `length` param is given, only that amount will be read from the soundfile.
        Use the `start` param to specify a position (seconds) in the soundfile to begin reading from.
        No samplerate conversion is done (yet) so be careful to match the samplerate of the start param with that 
        of the soundfile being read. (Or don't!)
        Overflows (reading beyond the boundries of the file) are filled with silence so the length 
        param is always respected and will return a SoundBuffer of the requested length. This is 
        just a wrapper around pysndfile's soundfile.read method.

        Data loaded via the `buf` keyword must be interpretable by cython as a memoryview on a 2D array 
        of doubles. (A numpy ndarray for example.)

        Single channel (1D) data loaded via the `frames` keyword will be copied into the given number of channels
        specified by the `channels` param. (And if no value is given, a mono SoundBuffer will be created.) 
        Handy for doing synthesis prototyping with python lists.

        Multichannel (2D) data loaded via the `frames` keyword will ignore the `channels` 
        param and adapt to what was given by attempting to read the data into a numpy array
        and take the number of channels from its shape.
        
        The remaining sources (`filename`, `buf`) will use the number of channels found in the 
        data and ignore the value passed to the SoundBuffer initializer.

        If none of those sources are present, but a `length` param has been given, 
        the SoundBuffer will be initialized with silence to the given length in seconds.
        
        Otherwise an empty SoundBuffer is created with a length of zero.
    """

    def __cinit__(SoundBuffer self, 
            object frames=None, 
            double length=-1, 
               int channels=DEFAULT_CHANNELS, 
               int samplerate=DEFAULT_SAMPLERATE, 
           unicode filename=None, 
            double start=0, 
       double[:,:] buf=None):
        self.samplerate = samplerate
        self.channels = max(channels, 1)
        cdef int framestart = 0
        cdef int framelength = <int>(length * self.samplerate)
        cdef double[:] tmplist

        if filename is not None:
            framestart = <int>(start * self.samplerate)
            self.frames, self.samplerate = soundfile.read(filename, framelength, framestart, dtype='float64', fill_value=0, always_2d=True)
            self.channels = self.frames.shape[1]

        elif buf is not None:
            self.frames = buf
            self.channels = self.frames.shape[1]

        elif frames is not None:
            if isinstance(frames, Wavetable):
                self.frames = np.column_stack([ frames.data for _ in range(self.channels) ])

            elif isinstance(frames, list):
                tmplist = np.array(frames, dtype='d')
                self.frames = np.column_stack([ tmplist for _ in range(self.channels) ])

            elif frames.shape == 1:
                self.frames = np.column_stack([ frames for _ in range(self.channels) ])

            elif frames.shape != self.channels:
                self.frames = _remix(frames, len(frames), self.channels)

            else:
                self.frames = np.array(frames, dtype='d')
                self.channels = self.frames.shape[1]

        elif length > 0:
            self.frames = np.zeros((framelength, self.channels))
        else:
            self.frames = None


    #############################################
    # (+) Addition & concatenation operator (+) #
    #############################################
    def __add__(SoundBuffer self, object value):
        """ Add a number to every sample in this SoundBuffer or concatenate with another 
            SoundBuffer or iterable with compatible dimensions
        """
        if self.frames is None:
            if isinstance(value, numbers.Real):
                return SoundBuffer(channels=self.channels, samplerate=self.samplerate)
            elif isinstance(value, SoundBuffer):
                return value.copy()
            else:
                return SoundBuffer(value, channels=self.channels, samplerate=self.samplerate)

        cdef int length = len(self.frames)
        cdef double[:,:] out = np.zeros((length, self.channels))

        if isinstance(value, numbers.Real):
            out = np.add(self.frames, value)
        elif isinstance(value, SoundBuffer):
            if value.channels != self.channels:
                value = value.remix(self.channels)

            if value.frames is None:
                out = self.frames.copy()
            else:
                out = np.vstack((self.frames, value.frames))
        else:
            try:
                out = np.vstack((self.frames, value))
            except TypeError as e:
                return NotImplemented

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    def __iadd__(SoundBuffer self, object value):
        """ In place add either adding number to every value without copy, or 
            directly extending internal frame buffer.
        """
        if self.frames is None:
            if isinstance(value, numbers.Real):
                return self
            elif isinstance(value, SoundBuffer):
                return value.copy()
            else:
                return SoundBuffer(value, channels=self.channels, samplerate=self.samplerate)

        cdef SoundBuffer out

        if isinstance(value, numbers.Real):
            self.frames = np.add(self.frames, value)
        elif isinstance(value, SoundBuffer):
            if value.channels != self.channels:
                value = value.remix(self.channels)
            self.dub(value, self.dur)
        else:
            try:
                self.frames = np.vstack((self.frames, value))
            except TypeError as e:
                return NotImplemented

        return self

    def __radd__(SoundBuffer self, object value):
        return self + value

    cpdef SoundBuffer adsr(SoundBuffer self, double a=0, double d=0, double s=1, double r=0):
        self.frames = sb_adsr(self.frames, <int>len(self), <int>self.channels, <double>self.samplerate, a, d, s, r)
        return self

    ########################
    # (&) Mix operator (&) #
    ########################
    def __and__(SoundBuffer self, object value):
        """ Mix two SoundBuffers or two 2d arrays with compatible dimensions

            >>> sound = SoundBuffer(length=1, channels=2, samplerate=44100)
            >>> sound2 = SoundBuffer(length=0.35, channels=2, samplerate=44100)
            >>> out = sound2 & sound
            >>> len(out)
            1.0
        """

        cdef double[:,:] out
        cdef double[:,:] a, b
        cdef int i, c
        cdef int channels = self.channels

        if isinstance(value, SoundBuffer):
            if len(self.frames) > len(value.frames):
                a = self.frames
                b = value.frames
            else:
                a = value.frames
                b = self.frames

        else:
            if len(self.frames) > len(value):
                a = self.frames
                b = np.array(value, dtype='d')
            else:
                a = np.array(value, dtype='d')
                b = self.frames

        if a.shape[1] > b.shape[1]:
            b = _remix(b, len(b), a.shape[1])
            channels = a.shape[1]
        elif b.shape[1] > a.shape[1]:
            a = _remix(a, len(a), b.shape[1])

        out = a.copy()
        for i in range(len(b)):
            for c in range(channels):
                out[i,c] += b[i,c]

        return SoundBuffer(out, channels=channels, samplerate=self.samplerate)

    def __iand__(SoundBuffer self, object value):
        """ Mix in place two SoundBuffers or two 2d arrays with compatible dimensions
        """
        # TODO: avoid a copy for cases where internal buffer 
        # is greater than or equal to the length of the value
        cdef double[:,:] out
        cdef double[:,:] a, b
        cdef int i, c
        cdef int channels = self.channels

        if isinstance(value, SoundBuffer):
            if len(self.frames) > len(value.frames):
                a = self.frames
                b = value.frames
            else:
                a = value.frames
                b = self.frames

        else:
            if len(self.frames) > len(value):
                a = self.frames
                b = np.array(value, dtype='d')
            else:
                a = np.array(value, dtype='d')
                b = self.frames

        if a.shape[1] > b.shape[1]:
            b = _remix(b, len(b), a.shape[1])
            channels = a.shape[1]
        elif b.shape[1] > a.shape[1]:
            a = _remix(a, len(a), b.shape[1])

        out = a.copy()
        for i in range(len(b)):
            for c in range(channels):
                out[i,c] += b[i,c]

        self.frames = out
        self.channels = channels
        return self

    def __rand__(SoundBuffer self, object value):
        return self & value


    ##############
    # Truthiness #
    ##############
    def __bool__(self):
        return bool(len(self))

    def __eq__(self, other):
        try:
            return len(self) == len(other) and all(a == b for a, b in zip(self, other))
        except TypeError as e:
            return NotImplemented


    #############################
    # ([:]) Frame slicing ([:]) #
    #############################
    def __getitem__(self, position):
        """ Slice into this SoundBuffer, returning a copy of a portion of the buffer, 
            or a tuple of samples representing a single frame.

            >>> sound = SoundBuffer(length=1, samplerate=44100, channels=2)
            >>> bit = sound[0:4410]
            >>> len(bit)
            0.1
            >>> sound[0]
            (0,0)
        """
        if isinstance(position, int):
            return tuple(self.frames[<int>position])

        cdef double[:, :] out

        if not position.stop:
            out = self.frames[position.start:]

        elif not position.start:
            out = self.frames[:position.stop]

        else:
            out = self.frames[position.start:position.stop]

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)


    ###########################
    # Lengthiness & sizeyness #
    ###########################
    def __len__(self):
        """ Return the length of this SoundBuffer in frames.

                >>> sound = SoundBuffer(length=1, samplerate=44100, channels=2)
                >>> len(sound)
                44100
        """
        return 0 if self.frames is None else len(self.frames)

    @property
    def dur(self):
        """ Duration of the SoundBuffer in seconds
        """
        return len(self) / <double>self.samplerate

    @property
    def mag(self):
        """ Magnitude of the SoundBuffer as a float.
            Multichannel SoundBuffers are not summed -- 
            this returns the largest absolute value in any channel.
        """
        return _mag(self.frames)

    @property
    def avg(self):
        """ Average magnitude of the SoundBuffer as a float.
            The average is taken from the absolute value 
            (magnitude) of all channels.
        """
        return np.mean(np.abs(self.frames), dtype='d')

    ###################################
    # (*) Multiplication operator (*) #
    ###################################
    def __mul__(self, value):
        """ Multiply a SoundBuffer by a number, iterable or SoundBuffer and return a new SoundBuffer

                >>> sound = SoundBuffer(length=1, channels=2, samplerate=44100)

                # Multiply every sample in `sound` by 0.5
                >>> sound *= 0.5

                # Multiply every sample by an interpolated copy of `wavetable` 
                # `wavetable` can be a 1d flat array/list/iterable, or a SoundBuffer
                # This will modulate the amplitude of the SoundBuffer with the wavetable.
                >>> wavetable = [0, 0.25, 0.5, 0.25, 0.75, 1]
                >>> sound = sound * wavetable

                >>> sound2 = SoundBuffer(length=0.5, channels=2, samplerate=44100)
                >>> sound = sound * sound2
        """
        cdef int length = len(self.frames)
        cdef double[:,:] out
        cdef double[:] wavetable

        if isinstance(value, numbers.Real):
            out = np.multiply(self.frames, value)

        elif isinstance(value, SoundBuffer):
            out = _mul2d(self.frames, value.frames)

        elif isinstance(value, Wavetable):
            out = _mul1d(self.frames, value.data)

        elif isinstance(value, list):
            out = _mul1d(self.frames, np.array(value))

        else:
            try:
                if len(value.shape) == 1:
                    out = _mul1d(self.frames, value)
                else:
                    out = _mul2d(self.frames, value)
            except TypeError:
                return NotImplemented

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    def __imul__(self, value):
        """ Multiply a SoundBuffer in place by a number, iterable or SoundBuffer
        """
        if isinstance(value, numbers.Real):
            self.frames = np.multiply(self.frames, value)

        elif isinstance(value, SoundBuffer):
            self.frames = _mul2d(self.frames, value.frames)

        elif isinstance(value, list):
            self.frames = _mul1d(self.frames, np.array(value))

        else:
            try:
                if len(value.shape) == 1:
                    self.frames = _mul1d(self.frames, value)
                else:
                    self.frames = _mul2d(self.frames, value)
            except TypeError:
                return NotImplemented

        return self

    def __rmul__(self, value):
        return self * value


    ################################
    # (-) Subtraction operator (-) #
    ################################
    def __sub__(self, value):
        """ Subtract a number from every sample in this SoundBuffer or  
            from another SoundBuffer or iterable with compatible dimensions
        """
        cdef double[:,:] out

        if isinstance(value, numbers.Real):
            out = np.subtract(self.frames, value)
        elif isinstance(value, SoundBuffer):
            out = np.subtract(self.frames, value.frames)
        else:
            try:
                out = np.subtract(self.frames, value[:,None])
            except TypeError as e:
                return NotImplemented

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    def __isub__(self, value):
        """ In place subtract a number from every sample in this SoundBuffer or  
            from another SoundBuffer or iterable with compatible dimensions
        """
        if isinstance(value, numbers.Real):
            self.frames = np.subtract(self.frames, value)
        elif isinstance(value, SoundBuffer):
            self.frames = np.subtract(self.frames, value.frames)
        else:
            try:
                self.frames = np.subtract(self.frames, value.frames)
            except TypeError as e:
                return NotImplemented

        return self

    def __rsub__(self, value):
        return self - value


    ##############################
    # Pickling & stringification #
    ##############################
    def __reduce__(self):
        """ Tells the pickle module how to rebuild a pickled instance of a SoundBuffer
        """
        return (rebuild_buffer, (np.asarray(self.frames), self.channels, self.samplerate))

    def __repr__(self):
        """ Return a string representation of this SoundBuffer
        """
        return 'SoundBuffer(samplerate=%s, channels=%s, frames=%s, dur=%.2f)' % (self.samplerate, self.channels, len(self.frames), self.dur)


    ##########################
    # Transformation methods #
    ##########################
    def clear(self, int length=-1):
        """ Writes zeros into the buffer, adjusting the
            size if length > 0.
        """
        if length <= 0:
            self.frames = None
        else:
            self.frames = np.zeros((length, self.channels))

    def cloud(SoundBuffer self, double length=-1, *args, **kwargs):
        """ Create a new Cloud from this SoundBuffer
        """
        return grains.Cloud(self, *args, **kwargs).play(length)

    def copy(self):
        """ Return a new copy of this SoundBuffer.
        """
        if self.frames is None:
            return SoundBuffer(channels=self.channels, samplerate=self.samplerate)
        return SoundBuffer(np.array(self.frames, copy=True), channels=self.channels, samplerate=self.samplerate)

    def clip(self, minval=-1, maxval=1):
        return SoundBuffer(np.clip(self.frames, minval, maxval), channels=self.channels, samplerate=self.samplerate)

    def softclip(SoundBuffer self):
        return fx.softclip(self)
        
    cpdef SoundBuffer convolve(SoundBuffer self, object impulse, bint norm=True):
        cdef double[:,:] _impulse
        cdef double[:] _wt

        if isinstance(impulse, str):
            _wt = to_window(impulse)
            _impulse = np.hstack([ _wt for _ in range(self.channels) ])

        elif isinstance(impulse, Wavetable):
            _impulse = np.hstack([ np.reshape(impulse.data, (-1, 1)) for _ in range(self.channels) ])

        elif isinstance(impulse, SoundBuffer):
            if impulse.channels != self.channels:
                _impulse = impulse.remix(self.channels).frames
            else:
                _impulse = impulse.frames

        else:
            raise TypeError('Could not convolve impulse of type %s' % type(impulse))

        cdef double[:,:] out = fft.conv(self.frames, _impulse)

        if norm:
            out = fx._norm(out, self.mag)

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    def cut(self, double start=0, double length=1):
        """ Copy a portion of this soundbuffer, returning 
            a new soundbuffer with the selected slice.

            This is called `cut` for historical reasons, but it 
            might be better understood if renamed to `slice` as it 
            doesn't modify the source SoundBuffer in any way.
            
            The `start` param is a position in seconds to begin 
            cutting, and the `length` param is the cut length in seconds.

            Overflowing values that exceed the boundries of the source SoundBuffer 
            will return a SoundBuffer padded with silence so that the `length` param 
            is always respected.
        """
        cdef int readstart = <int>(start * self.samplerate)
        cdef int outlength = <int>(length * self.samplerate)
        cdef int readend = outlength + readstart
        cdef int readlength = len(self) - readstart

        cdef double[:,:] out = np.zeros((outlength, self.channels))
        if readlength >= 0:
            out[0:readlength] = self.frames[readstart:readend]

        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    def rcut(self, double length=1):
        """ Copy a portion of this SoundBuffer of the 
            given length in seconds starting from a random 
            position within it. 
            
            This will always return a complete SoundBuffer 
            without overflows or added silence, and the entire 
            sound will be returned without added silence if a length 
            that exceeds the length of the source SoundBuffer is given -- 
            unlike SoundBuffer.cut() which will pad results with silence 
            to preserve the length param if an invalid or overflowing offset 
            position is given.
        """
        cdef double maxlen = self.dur - length
        if maxlen <= 0:
            return self
        cdef double start = random.triangular(0, maxlen)
        return self.cut(start, length)

    cdef void _dub(SoundBuffer self, SoundBuffer sound, int framepos):
        cdef int target_length = len(self)
        cdef int todub_length = len(sound)
        cdef int total_length = framepos + todub_length
        cdef int channels = self.channels

        if target_length == 0:
            self.frames = np.zeros((total_length, channels), dtype='d')
            target_length = total_length
        elif target_length < total_length:
            self.frames = np.vstack((
                    self.frames.copy(), 
                    np.zeros((total_length - target_length, channels), dtype='d')
                ))
            target_length = len(self)

        self.frames = _dub(self.frames, target_length, sound.frames, todub_length, channels, framepos)

    def dub(self, sounds, double pos=-1, int framepos=0):
        """ Dub a sound or iterable of sounds into this soundbuffer
            starting at the given position in fractional seconds.

                >>> snd.dub(snd2, 3.2)

            To dub starting at a specific frame position use:

                >>> snd.dub(snd3, framepos=111)
        """
        cdef int numsounds
        cdef int sound_index

        if pos >= 0:
            framepos = <int>(pos * self.samplerate)

        if isinstance(sounds, SoundBuffer):
            self._dub(sounds, framepos)
        else:
            numsounds = len(sounds)
            try:
                for sound_index in range(numsounds):
                    self._dub(sounds[sound_index], framepos)

            except TypeError as e:
                raise TypeError('Please provide a SoundBuffer or list of SoundBuffers for dubbing') from e

    def env(self, object window=None):
        """ Apply an amplitude envelope 
            to the sound of the given type.

            To modulate a sound with an arbitrary 
            iterable, simply do:

                >>> snd * iterable

            Where iterable is a list, array, or SoundBuffer with 
            the same # of channels and of any length
        """
        if window is None:
            window = 'sine'
        cdef int length = len(self)
        return self * to_window(window, length)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void _fill(self, double[:,:] frames):
        """ Fill current w/frames
        """
        cdef int frame_index, channel_index = 0
        cdef int framelen = len(frames)
        cdef int length = len(self.frames)
        cdef int minlen = min(framelen, length)

        for frame_index in range(minlen):
            for channel_index in range(self.channels):
                self.frames[frame_index][channel_index] = frames[frame_index][channel_index]

    def fill(self, int length):
        """ Truncate the buffer to the given length or 
            loop the contents of the buffer up to the 
            given length in frames.
        """
        cdef int mult = 0 if length <= 0 or len(self) == 0 else length // len(self)
        out = SoundBuffer(frames=self.frames[:,:], channels=self.channels, samplerate=self.samplerate)

        if mult > 1:
            out = out.repeat(mult)

        return out[:length]

    def grains(self, double minlength, double maxlength=-1):
        """ Iterate over the buffer in fixed-size grains.
            If a second length is given, iterate in randomly-sized 
            grains, given the minimum and maximum sizes.
        """
        minlength = min(max(0, minlength), self.dur)
        if maxlength > 0:
            maxlength = min(self.dur, maxlength)

        if minlength == 0 or minlength == maxlength:
            yield self
            return

        cdef int framesread = 0
        cdef int maxframes = <int>(maxlength * self.samplerate) 
        cdef int minframes = <int>(minlength * self.samplerate)
        cdef int grainlength = minframes
        cdef int sourcelength = len(self)
        while framesread < sourcelength:
            if minlength > 0 and maxlength > 0:
                grainlength = random.randint(minframes, maxframes)

            yield self[framesread:framesread+grainlength]

            framesread += grainlength

    def graph(SoundBuffer self, *args, **kwargs):
        return graph.write(self, *args, **kwargs)

    def max(self):
        return np.amax(self.frames)
 
    def mix(self, sounds):
        """ Mix this sound in place with a sound or iterable of sounds
        """
        cdef SoundBuffer sound
        cdef int numsounds
        cdef int sound_index
        if isinstance(sounds, SoundBuffer):
            self &= sounds
        else:
            numsounds = len(sounds)
            try:
                for sound_index in range(numsounds):
                    self &= sounds[sound_index] 
            except TypeError as e:
                raise TypeError('Please provide a SoundBuffer or list of SoundBuffers for mixing') from e

    def pad(self, double start=0, double end=0, bint samples=False):
        """ Pad this sound with silence at start or end
        """
        if start <= 0 and end <= 0: 
            return self

        cdef int framestart, frameend

        if not samples:
            framestart = <int>(start * self.samplerate)
            frameend = <int>(end * self.samplerate)
        else:
            framestart = <int>start
            frameend = <int>end

        cdef double[:,:] out = self.frames

        if framestart > 0:
            out = np.vstack((np.zeros((framestart, self.channels)), out))

        if frameend > 0:
            out = np.vstack((out, np.zeros((frameend, self.channels))))
 
        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    cpdef SoundBuffer pan(SoundBuffer self, object pos=0.5, str method=None):
        """ Pan a stereo sound from `pos=0` (hard left) to `pos=1` (hard right)

            Different panning strategies can be chosen by passing a value to the `method` param.

            - `method='constant'` Constant (square) power panning. This is the default.
            - `method='linear'` Simple linear panning.
            - `method='sine'` Variation on constant power panning using sin() and cos() to shape the pan. _Taken from the floss manuals csound manual._
            - `method='gogins'` Michael Gogins' variation on the above which uses a different part of the sinewave. _Also taken from the floss csound manual!_
        """
        if method is None:
            method = 'constant'

        cdef double[:,:] out = self.frames
        cdef int length = len(self)
        cdef int channel = 0
        cdef double[:] _pos = to_window(pos)
        out = _pan(out, length, self.channels, _pos, to_flag(method))
        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    def remix(self, int channels):
        return SoundBuffer(_remix(self.frames, len(self.frames), channels), samplerate=self.samplerate, channels=channels)

    def repeat(self, int reps=2):
        if reps <= 1:
            return SoundBuffer(self.frames, samplerate=self.samplerate, channels=self.channels)

        cdef double length = reps * self.dur
        out = SoundBuffer(length=length, channels=self.channels, samplerate=self.samplerate)

        for _ in range(reps):
            out.dub(self)

        return out

    def reverse(self):
        self.frames = np.flip(self.frames, 0)

    def reversed(self):
        return SoundBuffer(np.flip(self.frames, 0), channels=self.channels, samplerate=self.samplerate)

    def speed(self, double speed, int scheme=LINEAR):
        """ Change the speed of the sound
        """
        cdef int framelength = len(self)
        cdef double[:] chan = np.zeros(framelength, dtype='d')

        speed = speed if speed > 0 else 0.001
        cdef int length = <int>(framelength * (1.0 / speed))

        cdef double[:,:] out = np.zeros((length, self.channels), dtype='d')
        cdef double[:] outchan = np.zeros(length, dtype='d')

        out = _speed(self.frames, out, chan, outchan, <int>self.channels)
        return SoundBuffer(out, channels=self.channels, samplerate=self.samplerate)

    cpdef SoundBuffer vspeed(SoundBuffer self, object speed):
        cdef double[:] _s = to_window(speed)
        cdef double min_speed = max(min(_s), VSPEED_MIN)
        cdef int total_length = <int>(len(self.frames) * (1.0/min_speed))
        cdef np.ndarray frames = np.ndarray((len(self), self.channels), dtype='d', buffer=self.frames)
        cdef double[:,:] out = np.zeros((total_length, self.channels), dtype='d')
        cdef long framelength = len(self.frames)
        cdef int i = 0
        cdef double pos = 0
        cdef double phase = 0
        cdef double phase_inc = (1.0/framelength) * (framelength-1)

        for i in range(total_length):
            pos = phase / framelength
            for c in range(self.channels):
                out[i,c] = interpolation._linear_point(frames[:,c], phase)

            speed = interpolation._linear_pos(_s, pos)
            phase += phase_inc * speed
            if phase >= framelength:
                break

        return SoundBuffer(out[0:i], channels=self.channels, samplerate=self.samplerate)

    cpdef SoundBuffer stretch(SoundBuffer self, double length, object position=None, double amp=1.0):
        """ Change the length of the sound without changing the pitch. 
            Uses the csound `mincer` phase vocoder implementation from soundpipe.
        """
        if position is None:
            position = Wavetable('phasor', window=True)

        cdef double[:] time_lfo = to_window(position)
        cdef double[:] pitch_lfo = to_window(1.0)

        return SoundBuffer(soundpipe.mincer(self.frames, length, time_lfo, amp, pitch_lfo, 4096, self.samplerate), channels=self.channels, samplerate=self.samplerate)

    def taper(self, double length):
        cdef int framelength = <int>(self.samplerate * length)
        return self * _adsr(len(self), framelength, 0, 1, framelength)

    cpdef SoundBuffer transpose(SoundBuffer self, object speed, object length=None, object position=None, double amp=1.0):
        """ Change the pitch of the sound without changing the length.
            Uses the csound `mincer` phase vocoder implementation from soundpipe.
        """
        if length is None:
            length = self.dur

        if position is None:
            position = Wavetable('phasor', window=True)

        cdef double[:] time_lfo = to_window(position)
        cdef double[:] pitch_lfo = to_window(speed)

        return SoundBuffer(soundpipe.mincer(self.frames, length, time_lfo, amp, pitch_lfo, 4096, self.samplerate), channels=self.channels, samplerate=self.samplerate)

    cpdef SoundBuffer trim(SoundBuffer self, bint start=False, bint end=True, double threshold=0, int window=4):
        """ Trim silence below a given threshold from the end (and/or start) of the buffer
        """
        cdef int boundry = len(self)-1
        cdef int trimend = boundry
        cdef int trimstart = 0
        cdef double current = 0
        cdef int hits = 0

        if end:
            current = abs(sum(self.frames[trimend]))

            while True:
                if current > threshold:
                    hits += 1

                trimend -= 1

                if trimend <= 0 or hits >= window:
                    break

                current = abs(sum(self.frames[trimend]))

        if start:
            hits = 0
            current = abs(sum(self.frames[trimstart]))

            while True:
                if current > threshold:
                    hits += 1

                trimstart += 1

                if trimstart >= boundry or hits >= window:
                    break

                current = abs(sum(self.frames[trimstart]))

        return self[trimstart:trimend].copy()

    cpdef Wavetable toenv(SoundBuffer self, double window=0.015):
        return fx.envelope_follower(self, window)

    def towavetable(SoundBuffer self, *args, **kwargs):
        return Wavetable(self, *args, **kwargs)

    def write(self, unicode filename=None):
        """ Write the contents of this buffer to disk 
            in the given audio file format. (WAV, AIFF, AU)
        """
        return soundfile.write(filename, self.frames, self.samplerate)


cpdef object rebuild_buffer(double[:,:] frames, int channels, int samplerate):
    return SoundBuffer(frames, channels=channels, samplerate=samplerate)


