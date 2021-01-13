#cython: language_level=3

from pippi.defaults cimport DEFAULT_KEY
from pippi.frequtils cimport key_to_freq
from pippi.scales cimport DEFAULT_RATIOS

INTERVALS = {
    'P1': 0, 
    'm2': 1, 
    'M2': 2, 
    'm3': 3, 
    'M3': 4, 
    'P4': 5, 
    'TT': 6, 
    'P5': 7, 
    'm6': 8, 
    'M6': 9, 
    'm7': 10, 
    'M7': 11,
    'P8': 12,
    'm9': 13,
    'M9': 14,
    'm10': 15,
    'M10': 16,
    'P11': 17,
    'd12': 18, # TT + P8
    'P12': 19,
    'm13': 20,
    'M13': 21,
    'm14': 22,
    'M14': 23,
    'P15': 24
}


def get_ratio_from_interval(iv, ratios):
    index = INTERVALS[iv]

    try:
        ratio = ratios[index]
        ratio = ratio[0] / ratio[1]
    except IndexError:
        base_index = index % 12
        ratio = ratios[base_index]
        ratio = ratio[0] / ratio[1]

        register = (index - base_index) / 12
        ratio *= 2**register

    return ratio

def apply_interval(freq, iv=None, ratios=None):
    if iv is None:
        iv = 'P1'
    if ratios is None:
        ratios = DEFAULT_RATIOS
    return freq * get_ratio_from_interval(iv, ratios)

def add_intervals(a, b):
    a = INTERVALS[a]
    b = INTERVALS[b]
    c = a + b
    for iv, index in INTERVALS.items():
        if c == index:
            return iv
    return None

def intervals(intervals, name=None, key=None, octave=3, ratios=None):
    if key is None:
        key = DEFAULT_KEY

    if ratios is None:
        ratios = DEFAULT_RATIOS

    if isinstance(intervals, str):
        intervals = [ interval for interval in intervals.split(' ') if interval != '' ]

    root_freq = key_to_freq(key, octave, ratios, name)

    _ratios = [ get_ratio_from_interval(interval, ratios) for interval in intervals ]
    return [ root_freq * ratio for ratio in _ratios ]


