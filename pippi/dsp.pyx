#cython: language_level=3

import glob
import math
import multiprocessing as mp
import numpy as np
from pathlib import Path
import random

cimport cython
import soundfile

from pippi.events cimport Event
from pippi.events cimport render as _render
from pippi.soundbuffer import SoundBuffer
from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport Wavetable, _randline
from pippi.wavesets cimport Waveset
from pippi cimport rand as _rand
from pippi cimport lists
from pippi.sounddb cimport SoundDB
from pippi.defaults cimport DEFAULT_CHANNELS, DEFAULT_SAMPLERATE

# Just a shorthand for MS in scripts. 
# For example:
#
# >>> snd.cut(0.75, 32*dsp.MS)
#
# Which cuts, starting from 0.75 seconds in, 
# a 32 millisecond section from the SoundBuffer `snd`.
MS = 0.001

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef double _mag(double[:,:] snd):
    cdef int i = 0
    cdef int c = 0
    cdef int framelength = len(snd)
    cdef int channels = snd.shape[1]
    cdef double maxval = 0

    for i in range(framelength):
        for c in range(channels):
            maxval = max(maxval, abs(snd[i,c]))

    return maxval

cpdef double mag(SoundBuffer snd):
    return _mag(snd.frames)

cpdef list scale(list source, double fromlow=-1, double fromhigh=1, double tolow=0, double tohigh=1, bint log=False):
    cdef unsigned int length = len(source)
    cdef double[:] out = np.zeros(length, dtype='d')
    cdef double[:] _source = np.array(source, dtype='d')
    return np.array(lists._scale(out, _source, fromlow, fromhigh, tolow, tohigh, log), dtype='d').tolist()

cpdef list snap(list source, double mult=0, object pattern=None):
    return lists.snap(source, mult, pattern)

cpdef SoundBuffer mix(list sounds, align_end=False):
    """ Mix a list of sounds into a new sound
    """
    cdef double maxlength = 0
    cdef int maxchannels = 1
    cdef SoundBuffer sound

    for sound in sounds:
        maxlength = max(maxlength, sound.dur)
        maxchannels = max(maxchannels, sound.channels)

    cdef SoundBuffer out = SoundBuffer(length=maxlength, channels=maxchannels)

    if align_end:
        for sound in sounds:
            out.dub(sound, maxlength - sound.dur)
    else:
        for sound in sounds:
            out.dub(sound, 0)

    return out
    
cpdef Wavetable randline(int numpoints, double lowvalue=0, double highvalue=1, int wtsize=4096):
    return _randline(numpoints, lowvalue, highvalue, wtsize)

cpdef SoundDB injest(SoundBuffer snd, str dbname=None, object dbpath=None, bint overwrite=False):
    return SoundDB(snd, dbname, dbpath, overwrite)

def event(*args, **kwargs):
    return Event(*args, **kwargs)

cpdef SoundBuffer render(list events, object callback, int channels=DEFAULT_CHANNELS, int samplerate=DEFAULT_SAMPLERATE):
    return _render(events, callback, channels, samplerate)

cpdef Wavetable wt(object values, 
        object lowvalue=None, 
        object highvalue=None, 
        int wtsize=0, 
    ):
    return Wavetable(values, lowvalue, highvalue, wtsize, False)

cpdef Waveset ws(object values=None, object crossings=3, int offset=-1, int limit=-1, int modulo=1, int samplerate=-1, list wavesets=None):
    return Waveset(values, crossings, offset, limit, modulo, samplerate, wavesets)

cpdef Wavetable win(object values, 
        object lowvalue=None, 
        object highvalue=None, 
        int wtsize=0, 
    ):
    return Wavetable(values, lowvalue, highvalue, wtsize, True)

cpdef SoundBuffer stack(list sounds):
    cdef int channels = 0
    cdef unsigned int length = 0

    cdef SoundBuffer sound
    for sound in sounds:
        channels += sound.channels
        length = max(len(sound), length)

    cdef double[:,:] out = np.zeros((length, channels), dtype='d')

    cdef int j=0, c=0
    for sound in sounds:
        for c in range(sound.channels):
            for i in range(len(sound)):
                out[i,j] = sound.frames[i,c]
            j += 1

    return SoundBuffer(out, channels=channels, samplerate=sounds[0].samplerate)

def join(sounds, overlap=None, channels=None, samplerate=None):
    """ Concatenate a list of sounds into a new sound
    """
    channels = channels or sounds[0].channels
    samplerate = samplerate or sounds[0].samplerate

    cdef double total_length = 0
    cdef SoundBuffer sound

    for sound in sounds:
        total_length += sound.dur
        if overlap is not None:
            total_length -= overlap

    out = SoundBuffer(length=total_length, channels=channels, samplerate=samplerate)

    pos = 0
    for sound in sounds:
        out.dub(sound, pos)
        pos += sound.dur
        if overlap is not None:
            pos -= overlap

    return out

cpdef SoundBuffer buffer(object frames=None, double length=-1, int channels=2, int samplerate=44100):
    return SoundBuffer.__new__(SoundBuffer, frames=frames, length=length, channels=channels, samplerate=samplerate)

cpdef Wavetable load(object filename):
    frames, samplerate = soundfile.read(filename, dtype='float64', always_2d=False)
    return Wavetable(frames)

cpdef SoundBuffer read(object filename, double length=-1, double start=0):
    """ Read a soundfile from disk and return a `SoundBuffer` with its contents.
        May include a start position and length in seconds to read a segment from a large file.

        The `filename` param is always converted to a string, so it is safe to pass a 
        `Path` instance from the standard library `pathlib` module.
    """
    return SoundBuffer(filename=str(filename), length=length, start=start)

cpdef list readall(str path, double length=-1, double start=0):
    return [ read(filename, length, start) for filename in Path('.').glob(path) ]

cpdef double rand(double low=0, double high=1):
    return _rand.rand(low, high)

cpdef int randint(int low=0, int high=1):
    return _rand.randint(low, high)

cpdef object choice(list choices):
    return _rand.choice(choices)

cpdef void seed(object value=None):
    _rand.seed(value)

def find(pattern, channels=2, samplerate=44100):
    """ Glob for files matching a given pattern and return a generator 
        that will `yield` each file as a `SoundBuffer`
    """
    for filename in glob.iglob(pattern, recursive=True):
        yield SoundBuffer(channels=channels, samplerate=samplerate, filename=filename)

def pool(callback, reps=None, params=None, processes=None):
    out = []
    if params is None:
        params = [(None,)]

    if reps is None:
        reps = len(params)

    if processes is None:
        processes = mp.cpu_count()

    with mp.Pool(processes=processes) as process_pool:
        for result in [ process_pool.apply_async(callback, params[i % len(params)]) for i in range(reps) ]:
            out += [ result.get() ]

    return out

def fill(data, length):
    reps = math.ceil(length / len(data))
    if reps < 2:
        return data

    data = np.hstack([ data for _ in range(reps) ])
    return data[:length]

