#cython: language_level=3

import re

from pippi.defaults cimport a0
from pippi.scales cimport DEFAULT_RATIOS
from pippi.chords cimport name_to_index

# Maps to CHROMATIC ratio lists from tune.scales module
NOTES = { 
    'a': 0,
    'a#': 1,
    'bb': 1, 
    'b': 2,
    'c': 3, 
    'c#': 4, 
    'db': 4, 
    'd': 5, 
    'd#': 6, 
    'eb': 6, 
    'e': 7, 
    'f': 8, 
    'f#': 9, 
    'gb': 9, 
    'g': 10, 
    'g#': 11, 
    'ab': 11, 
}

MIDI_NOTES = { # Is this even used anywhere?
    'a': 21,
    'a#': 22,
    'bb': 22,
    'b': 23, 
    'c': 24, 
    'c#': 25,
    'db': 25,
    'd': 26,
    'd#': 27,
    'eb': 27,
    'e': 28, 
    'f': 29, 
    'f#': 30, 
    'gb': 30, 
    'g': 31, 
    'g#': 32,
    'ab': 32,
}


cpdef key_to_freq(key, octave, ratios, name=None):
    if name is None:
        name = 'I'

    # Get the root freq from the key
    base_freq = ntf(key, octave, ratios)

    # Get the root interval from the chord roman
    root_interval = ratios[name_to_index(name)]

    # Calc root freq from the key & root interval
    return base_freq * (root_interval[0] / root_interval[1])

def parse_pitch_class(note, octave=None):
    note = note.lower()
    if re.match('[a-zA-Z]#?b?\d+', note) is not None:
        parsed = re.match('([a-zA-Z]#?b?)(\d+)', note)
        note = parsed.group(1)
        octave = int(parsed.group(2))

    if octave is None:
        octave = 4

    return note, octave

def ntm(note, octave=None):
    note, octave = parse_pitch_class(note, octave)
    note_index = nti(note)
    if note_index >= 3:
        octave -= 1
    return note_index + 21 + (octave * 12)

def nti(note):
    """ Note to index
            returns the index of enharmonic note names
            or False if not found
    """
    return NOTES.get(note, False)

def ntf(note, octave=None, ratios=None):
    """ Note to freq 
    """
    if ratios is None:
        ratios = DEFAULT_RATIOS

    note, octave = parse_pitch_class(note, octave)

    note_index = nti(note)
    mult = ratios[note_index][0] / ratios[note_index][1]

    if note_index >= 3:
        octave -= 1

    return mult * a0 * 2.0**octave

def stf(index):
    degree = index % 24
    octave = index / 24

    return (2 ** (degree / 24.0)) * (a0 / 4.0) * (2.0 ** octave)

def mtf(midi_note):
    return 2**((midi_note - 69) / 12.0) * 440.0

def fts(freq):
    # Try to find closest eq temp freq to input
    # Generate entire range of possible eq temp freqs
    all_freq = [ stf(index) for index in range(2**8) ]

    count = 0
    cfreq = 0
    while freq > cfreq and count < 2**8:
        cfreq = all_freq[count]
        count = count + 1

    count = count - 1

    return count % 55

def nts(note, octave):
    octave = octave if octave >= -2 else -2
    octave = octave if octave <= 8 else 8 

    degree = NOTES[note] * 2

    degree = degree + ((octave + 2) * 24) 

    return degree

def fit(freq, low=20, high=20000, get_change=False):
    """ fit the given freq within the given freq range, 
    by transposing up or down octaves """

    # need to fit at least an octave
    if high < low * 2:
        high = low * 2

    def shift(freq, low, high, octave_shift=0):
        if freq < low:
            return shift(freq * 2, low, high, octave_shift + 1)

        if freq > high:
            return shift(freq * 0.5, low, high, octave_shift - 1)

        return freq, octave_shift

    freq, octave = shift(freq, low, high)

    if octave == 0:
        mult = 1
    elif octave > 0:
        mult = 2**octave
    elif octave < 0:
        mult = 1.0 / (2**abs(octave))

    if get_change == True:
        return freq, mult
    else:
        return freq


