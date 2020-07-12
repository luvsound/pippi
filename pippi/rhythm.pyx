#cython: language_level=3

""" Some helpers for building and transforming onset lists
"""

from pippi cimport wavetables
from pippi cimport interpolation
from pippi cimport dsp
from pippi.soundbuffer cimport SoundBuffer
from pippi cimport seq as _seq
from pippi cimport rand
import pyparsing
import numpy as np

MIN_BEAT = 0.0001
REST_SYMBOLS = set(('0', '.', ' ', '-', 0, False))

CLAVE = {
    'son':      'x..x..x...x.x...', 
    'rumba':    'x..x...x..x.x...', 
    'bell':     'x..x..xx..x.x..x', 
    'tresillo': 'x..x..x.', 
}

SON = CLAVE['son']
RUMBA = CLAVE['rumba']
BELL = CLAVE['bell']
TRESILLO = CLAVE['tresillo']


cdef list _onsetswing(list onsets, double amount, double[:] beat, double length):
    """ Add MPC-style swing to a list of onsets.
        Amount is a value between 0 and 1, which 
        maps to a swing amount between 0% and 75%.
        Every odd onset will be delayed by
            
            beat length * swing amount

        This will only really work like MPC swing 
        when there is a run of notes, as rests 
        are not represented in onset lists (and 
        MPC swing just delays the upbeats).
    """
    if amount <= 0:
        return onsets

    cdef int i = 0
    cdef double onset = 0
    #cdef double delay_amount = beat * amount * 0.75

    for i, onset in enumerate(onsets):
        if i % 2 == 1:
            onsets[i] += interpolation._linear_pos(beat, onset/length) * amount * 0.75

    return onsets

cdef list _topositions(object p, double[:] beat, double length, double[:] smear):
    cdef double pos = 0
    cdef int count = 0
    cdef double delay = 0
    cdef double div = 1
    cdef double _beat
    cdef list out = []
    cdef bint subdiv = False

    while pos < length:
        index = count % len(p)
        event = p[index]
        _beat = interpolation._linear_pos(beat, pos/<double>length)
        _beat *= interpolation._linear_pos(smear, pos/<double>length)
        _beat = max(MIN_BEAT, _beat)

        if event in REST_SYMBOLS:
            count += 1
            pos += _beat / div
            continue

        elif event == '[':
            end = p.find(']', index) - 1
            div = len(p[index : end])
            count += 1
            continue

        elif event == ']':
            div = 1
            count += 1
            continue

        out += [ pos ]
        pos += _beat / div
        count += 1

    return out

cdef list _frompattern(
    object pat,            # Pattern
    double[:] beat,        # Length of a beat in seconds -- may be given as a curve
    double length=1,       # Output length in seconds 
    double swing=0,        # MPC swing amount 0-1
    double div=1,          # Beat subdivision
    object smear=1.0,      # Beat modulation
):
    cdef double[:] _smear = wavetables.to_window(smear)
    cdef double[:] _beat = np.divide(beat, div)
    positions = _topositions(pat, _beat, length, _smear)
    positions = _onsetswing(positions, swing, _beat, length)
    return positions


cdef class Seq:
    def __init__(Seq self, object beat=0.2):
        self.beat = wavetables.to_window(beat)
        self.drums = {}

    def add(self, name, 
            pattern=None, 
            callback=None, 
            double div=1, 
            double swing=0, 
            barcallback=None, 
            sounds=None, 
            smear=1.0
        ):
        self.drums[name] = dict(
            name=name, 
            pattern=pattern, 
            sounds=list(sounds or []), 
            callback=callback, 
            barcallback=barcallback, 
            div=div, 
            swing=swing, 
            smear=smear,
        )

    def update(self, name, **kwargs):
        self.drums[name].update(kwargs)

    def play(self, double length):
        cdef SoundBuffer out = SoundBuffer(length=length)
        cdef SoundBuffer bar
        cdef dict drum
        cdef list onsets
        cdef double onset
        cdef SoundBuffer clang
        cdef int count

        for k, drum in self.drums.items():
            bar = SoundBuffer(length=length)
            onsets = _frompattern(
                        drum['pattern'], 
                        beat=self.beat, 
                        length=length, 
                        swing=drum['swing'], 
                        div=drum['div'], 
                        smear=drum['smear']
                    )

            count = 0
            for onset in onsets:
                if drum.get('callback', None) is not None:
                    clang = drum['callback'](onset/length, count)
                elif len(drum['sounds']) > 0:
                    clang = SoundBuffer(filename=str(rand.choice(drum['sounds'])))
                else:
                    clang = SoundBuffer()
                bar.dub(clang, onset)
                count += 1

            if drum.get('barcallback', None) is not None:
                bar = drum['barcallback'](bar)
            out.dub(bar)

        return out

def pgen(numbeats, div=1, offset=0, reps=None, reverse=False):
    """ Pattern creation helper
    """
    pat = [ 1 if tick == 0 else 0 for tick in range(div) ]
    pat = [ pat[i % len(pat)] for i in range(numbeats) ]

    if offset > 0:
        pat = [ 0 for _ in range(offset) ] + pat[:-offset]

    if reps is not None:
        pat *= reps

    if reverse:
        pat = [ p for p in reversed(pat) ]

    return pat

def onsets(pattern, beat=0.2, length=30, smear=1):
    """ Patterns to onset lists
    """
    cdef double[:] _beat = wavetables.to_window(beat)
    cdef double[:] _smear = wavetables.to_window(smear)
    return _topositions(pattern, _beat, length, _smear)

def eu(length, numbeats, offset=0, reps=None, reverse=False):
    """ A euclidian pattern generator

        Length 6, numbeats 3
        >>> rhythm.eu(6, 3)
        [1, 0, 1, 0, 1, 0]

        Length 6, numbeats 3, offset 1
        >>> rhythm.eu(6, 3, 1)
        [0, 1, 0, 1, 0, 1]
    """
    pulses = [ 1 for pulse in range(numbeats) ]
    pauses = [ 0 for pause in range(length - numbeats) ]

    position = 0
    while len(pauses) > 0:
        try:
            index = pulses.index(1, position)
            pulses.insert(index + 1, pauses.pop(0))
            position = index + 1
        except ValueError:
            position = 0

    pattern = rotate(pulses, offset+len(pulses))

    if reps:
        pattern *= reps

    if reverse:
        pattern = [ p for p in reversed(pattern) ]

    return pattern

def rotate(pattern, offset=0):
    """ Rotate a pattern list by a given offset
    """
    return pattern[-offset % len(pattern):] + pattern[:-offset % len(pattern)]

def repeat(onsets, reps):
    """ Repeat a sequence of onsets a given number of times
    """
    out = []
    total = sum(onsets)
    for rep in range(reps):
        out += [ onset + (rep * total) for onset in onsets ]

    return out


