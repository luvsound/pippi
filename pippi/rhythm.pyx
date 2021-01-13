#cython: language_level=3

""" Some helpers for building and transforming onset lists
"""

from inspect import signature

from pippi cimport wavetables
from pippi cimport interpolation
from pippi import dsp
from pippi cimport dsp
from pippi.soundbuffer cimport SoundBuffer
from pippi.lists cimport rotate
from pippi cimport seq as _seq
from pippi cimport rand
from pippi.events cimport Event
import numpy as np

MIN_BEAT = 0.0001
REST_SYMBOLS = set(('.', '-', False, None))

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


def makesection(str k, dict instrument, double length, list onsets, bint stems, str stemsdir, str sectionname, int sectionindex):
    cdef SoundBuffer clang
    cdef SoundBuffer bar = SoundBuffer(length=length)
    cdef int count = 0
    cdef double onset
    cdef double beat

    """
    cdef dict ctx = {
        'pos': 0, 
        'count': 0, 
        'sectionname': sectionname, 
        'sectionindex': sectionindex,
    }
    """

    cdef Event ctx = Event(count=0, sectionname=sectionname, sectionindex=sectionindex, length=length)

    cdef bint showwarning = False

    for onset, event, beat in onsets:
        ctx.pos = onset/length
        ctx.onset = onset
        ctx.count = count
        ctx.event = event
        ctx.beat = beat

        if instrument.get('callback', None) is not None:
            sig = signature(instrument['callback'])
            if len(sig.parameters) > 1:
                showwarning = True
                clang = instrument['callback'](onset/length, count)
            else:
                clang = instrument['callback'](ctx)

        elif len(instrument['sounds']) > 0:
            clang = SoundBuffer(filename=str(rand.choice(instrument['sounds'])))
        else:
            clang = SoundBuffer()
        bar.dub(clang, onset)
        count += 1

    if instrument.get('barcallback', None) is not None:
        bar = instrument['barcallback'](bar)

    if stems:
        bar.write('%sstem-%s-%s-%s.wav' % (stemsdir, ctx.sectionname, ctx.sectionindex, k))

    if showwarning:
        print('WARNING: using old-style callback')
    return k, bar


cdef class Seq:
    def __init__(self, object beat=0.2):
        self.beat = wavetables.to_window(beat)
        self.instruments = {}

    def add(self, name, 
            pattern=None, 
            callback=None, 
            double div=1, 
            int numbeats=4,
            double swing=0, 
            barcallback=None, 
            sounds=None, 
            smear=1.0
        ):
        self.instruments[name] = dict(
            name=name, 
            pattern=pattern, 
            sounds=list(sounds or []), 
            callback=callback, 
            barcallback=barcallback, 
            numbeats=numbeats,
            div=div, 
            swing=swing, 
            smear=smear,
        )

    def update(self, name, **kwargs):
        self.instruments[name].update(kwargs)


    def _onsetswing(self, list onsets, double amount):
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

        for onset, event, beat in onsets:
            if i % 2 == 1:
                onsets[i][0] += beat * amount * 0.75
            i += 1

        return onsets

    def _topositions(self, str p, double[:] beat, double[:] smear):
        cdef double pos = 0
        cdef int count = 0
        cdef double delay = 0
        cdef double div = 1
        cdef double _beat
        cdef list out = []
        cdef bint subdiv = False
        cdef int numbeats = len(p)

        while count < numbeats:
            index = count % numbeats 
            event = p[index]
            _beat = interpolation._linear_pos(beat, count/<double>numbeats)
            _beat *= interpolation._linear_pos(smear, count/<double>numbeats)
            _beat = max(MIN_BEAT, _beat)

            if event in REST_SYMBOLS:
                count += 1
                pos += _beat / div
                continue

            elif event == '[':
                end = p.find(']', index) - 1
                div = len(p[index:end])
                count += 1
                continue

            elif event == ']':
                div = 1
                count += 1
                continue

            out += [[pos, event, _beat]]
            pos += _beat / div
            count += 1

        return pos, out

    def _frompattern(
        self,
        str pat,               # Pattern
        double[:] beat,        # Length of a beat in seconds -- may be given as a curve
        double swing=0,        # MPC swing amount 0-1
        double div=1,          # Beat subdivision
        object smear=1.0,      # Beat modulation
    ):
        cdef double[:] _smear = wavetables.to_window(smear)
        cdef double[:] _beat = np.divide(beat, div)

        length, positions = self._topositions(pat, _beat, _smear)
        positions = self._onsetswing(positions, swing)

        return length, positions

    def _expandpatterns(self, dict patterns, str patternseq, int numbeats):
        cdef str pattern = ''
        cdef str empty = '.' * numbeats
        for patternname in patternseq:
            if patternname not in patterns:
                pattern += empty
                continue

            if isinstance(patterns[patternname], str):
                for i in range(numbeats):
                    pattern += patterns[patternname][i % len(patterns[patternname])]
 
            else:
                try:
                    pat = patterns[patternname]()
                except TypeError as e:
                    print('WARNING: invalid pattern of type', type(patterns[patternname]))
                    continue

                for i in range(numbeats):
                    try:
                        val = next(pat)
                    except StopIteration as e:
                        pat = patterns[patternname]()
                        val = next(pat)

                    pattern += val
        
        return pattern

    def play(self, int numbeats, str patseq=None, bint stems=False, str stemsdir='', bint pool=False):
        cdef SoundBuffer out = SoundBuffer()
        cdef dict instrument
        cdef str expanded
        cdef list onsets 
        cdef list params = []
        cdef int adjusted_numbeats
        for k, instrument in self.instruments.items():
            pat = instrument['pattern']
            adjusted_numbeats = numbeats * instrument['div']
            if isinstance(pat, dict) and patseq is not None:
                expanded = self._expandpatterns(pat, patseq, adjusted_numbeats)
            else:
                if isinstance(pat, dict):
                    pat = pat.items()[0]
                expanded = ''.join([ pat[i % len(pat)] for i in range(adjusted_numbeats) ])

            length, onsets = self._frompattern(
                expanded, 
                beat=self.beat, 
                swing=instrument['swing'], 
                div=instrument['div'], 
                smear=instrument['smear']
            )

            params += [(k, instrument, length, onsets, stems, stemsdir, None, 0)]
       
        out = SoundBuffer(length=length)
        if pool: 
            for k, bar in dsp.pool(makesection, params=params):
                out.dub(bar)
        else:
            for p in params:
                k, bar = makesection(*p)
                out.dub(bar)

        return out

    def score(self, dict score, int barlength=4, bint stems=False, str stemsdir='', bint pool=False):
        cdef double length, sectionlength
        cdef dict instrument
        cdef list onsets, params
        cdef int subsectioncount
        cdef SoundBuffer out = SoundBuffer()

        mainposition = 0
        cdef int sectionindex = 0
        for sectionname in score.get('seq', []):
            section = score[sectionname]
            sectionlength = 0

            # Build params
            params = []
            for k, instrument in self.instruments.items():
                if k not in section:
                    continue

                pat = instrument['pattern']
                if isinstance(pat, str):
                    pat = {'a': pat}

                expandedpattern = self._expandpatterns(pat, section[k], barlength * instrument['div'])

                # for section in score, get subsection bars...
                length, onsets = self._frompattern(
                    expandedpattern,
                    beat=self.beat, 
                    swing=instrument['swing'], 
                    div=instrument['div'], 
                    smear=instrument['smear']
                )

                params += [(k, instrument, length, onsets, stems, stemsdir, sectionname, sectionindex)]
                sectionlength = max(sectionlength, length)
           
            sectionout = SoundBuffer(length=sectionlength)
            if pool: 
                for k, bar in dsp.pool(makesection, params=params):
                    sectionout.dub(bar)
            else:
                for p in params:
                    k, bar = makesection(*p)
                    sectionout.dub(bar)

            out.dub(sectionout, mainposition)
            mainposition += sectionlength
            sectionindex += 1

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

def onsets(pattern, object beat=0.2, double length=30, object smear=1):
    """ Patterns to onset lists
    """
    cdef double[:] _beat = wavetables.to_window(beat)
    cdef double[:] _smear = wavetables.to_window(smear)
    cdef double pos = 0
    cdef int count = 0
    cdef double delay = 0
    cdef double div = 1
    cdef double _b
    cdef list out = []
    cdef bint subdiv = False

    while pos < length:
        index = count % len(pattern)
        event = pattern[index]
        _b = interpolation._linear_pos(_beat, pos/<double>length)
        _b *= interpolation._linear_pos(_smear, pos/<double>length)
        _b = max(MIN_BEAT, _b)

        if event in REST_SYMBOLS:
            count += 1
            pos += _b / div
            continue

        elif event == '[':
            end = pattern.find(']', index) - 1
            div = len(pattern[index : end])
            count += 1
            continue

        elif event == ']':
            div = 1
            count += 1
            continue

        out += [ pos ]
        pos += _b / div
        count += 1

    return out


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

def repeat(onsets, reps):
    """ Repeat a sequence of onsets a given number of times
    """
    out = []
    total = sum(onsets)
    for rep in range(reps):
        out += [ onset + (rep * total) for onset in onsets ]

    return out


