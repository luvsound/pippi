#cython: language_level=3

import re
import random # FIXME use internal choice
from pippi.defaults cimport DEFAULT_KEY
from pippi.scales cimport DEFAULT_RATIOS
from pippi.scales import JUST
from pippi.frequtils import ntf, key_to_freq
from pippi.intervals import get_ratio_from_interval
from pippi.lists cimport rotate


MATCH_ROMAN = '[ivIV]?[ivIV]?[iI]?'
MATCH_BASE = '[#b/+*^0-9]+'

CHORD_ROMANS = {
    'i': 0,
    'ii': 2,
    'iii': 4,
    'iv': 5,
    'v': 7,
    'vi': 9,
    'vii': 11,
}

BASE_QUALITIES = {
    '^': ['P1', 'M3', 'P5'],   # major
    '-': ['P1', 'm3', 'P5'],   # minor
    '*': ['P1', 'm3', 'TT'],   # diminished 
    '+': ['P1', 'M3', 'm6'],   # augmented
}

EXTENSIONS = {
    # 7ths
    '7': ['m7'],        
    '-7': ['m7'],              
    '^7': ['M7'],         

    # 9ths
    '9': ['m7', 'M9'],     
    '-9': ['m7', 'M9'],      
    '^9': ['M7', 'M9'],       

    # 11ths
    '11': ['m7', 'M9', 'P11'],
    '-11': ['m7', 'M9', 'P11'],
    '^11': ['M7', 'M9', 'P11'],

    # 13ths
    '13': ['m7', 'M9', 'P11', 'm13'], 
    '-13': ['m7', 'M9', 'P11', 'm13'],
    '^13': ['M7', 'M9', 'P11', 'M13'],

    # 15ths
    '15': ['m7', 'M9', 'P11', 'm13', 'P15'], 
    '-15': ['m7', 'M9', 'P11', 'm13', 'P15'],
    '^15': ['M7', 'M9', 'P11', 'M13', 'P15'],

    # Add 6/9
    '69': ['M6', 'M9'],  
    '6': ['M6'],        
}

# Common root movements
PROGRESSIONS = {
    'I': ['iii', 'vi', 'ii', 'IV', 'V', 'vii*'],
    'i': ['VII', 'III', 'VI', 'ii*', 'iv', 'V', 'vii*'],
    'ii': ['V', 'vii*'],
    'iii': ['vi'],
    'III': ['VI'],
    'IV': ['V', 'vii*'],
    'iv': ['V', 'vii*'],
    'V': ['I', 'i'], # a pivot
    'v': ['I', 'i'], # a pivot
    'vi': ['ii', 'IV'],
    'VI': ['ii*', 'iv'],
    'vii*': ['I', 'i'], # a pivot
    'vii': ['I', 'i'], # a pivot
}


def next_chord(name):
    # No current refs internally... used w/ PROGRESSIONS
    base_name = re.sub(MATCH_BASE, '', name)
    return random.choice(PROGRESSIONS[base_name])

def name_to_extension(name):
    if '/' in name:
        name = name.split('/')[0]
    return re.sub(MATCH_ROMAN + '[/*+]?', '', name)

def name_to_quality(name):
    quality = '-' if name.islower() else '^'
    return '*' if re.match(MATCH_ROMAN + '[*]', name) is not None else quality

def name_to_intervals(name):
    quality = name_to_quality(name)
    extension = name_to_extension(name) 

    intervals = BASE_QUALITIES[quality]

    if extension != '':
        intervals = intervals + EXTENSIONS[extension]

    return intervals

cpdef name_to_index(name):
    # Chord name to index
    root = re.sub('[#b/+*^0-9]+', '', name).lower()
    root = CHORD_ROMANS[root]

    if '#' in name:
        root += 1

    if 'b' in name:
        root -= 1

    return root % 12

def name_to_bass(name, key, octave, ratios):
    # FIXME this works but is dumb
    if '/' not in name:
        return name, None
    bass = chord(name.split('/')[1], key, octave, ratios)[0]
    name = name.split('/')[0]
    return name, bass    

def chord(name, key=None, octave=3, ratios=None, inversion=None):
    if key is None:
        key = DEFAULT_KEY

    if ratios is None:
        ratios = DEFAULT_RATIOS

    name, bass = name_to_bass(name, key, octave, ratios)
    root_freq = key_to_freq(key, octave, ratios, name)

    # Strip # and b from chord name
    name = re.sub('[#b]+', '', name)

    # Get chord intervals
    intervals = name_to_intervals(name)

    _ratios = [ get_ratio_from_interval(iv, ratios) for iv in intervals ]
    freqs = [ root_freq * ratio for ratio in _ratios ]

    if inversion is not None:
        freqs = rotate(freqs, inversion)

    if bass is not None:
        if bass > freqs[0]:
            bass /= 2.0
        freqs = [ bass ] + freqs

    return freqs

def chords(names, key=None, octave=3, ratios=JUST):
    if key is None:
        key = DEFAULT_KEY

    return [ chord(name, key, octave, ratios) for name in names ]


