#cython: language_level=3

import math

from pippi.defaults cimport DEFAULT_KEY, a0
from pippi.frequtils import ntf

EQUAL = tuple([ 2**(i/12) for i in range(12) ])

JUST = ( 
    (1.0, 1.0),     # P1
    (16.0, 15.0),   # m2
    (9.0, 8.0),     # M2
    (6.0, 5.0),     # m3
    (5.0, 4.0),     # M3
    (4.0, 3.0),     # P4
    (45.0, 32.0),   # TT
    (3.0, 2.0),     # P5
    (8.0, 5.0),     # m6
    (5.0, 3.0),     # M6
    (9.0, 5.0),     # m7
    (15.0, 8.0),    # M7
)

TERRY = (
    (1.0, 1.0),     # P1  C
    (16.0, 15.0),   # m2  Db
    (10.0, 9.0),    # M2  D
    (6.0, 5.0),     # m3  Eb
    (5.0, 4.0),     # M3  E
    (4.0, 3.0),     # P4  F
    (64.0, 45.0),   # TT  Gb
    (3.0, 2.0),     # P5  G
    (8.0, 5.0),     # m6  Ab
    (27.0, 16.0),   # M6  A 
    (16.0, 9.0),    # m7  Bb
    (15.0, 8.0),    # M7  B
)

YOUNG = (
    (1.0, 1.0),       # P1 0
    (567.0, 512.0),   # m2 1
    (9.0, 8.0),       # M2 2
    (147.0, 128.0),   # m3 3
    (21.0, 16.0),     # M3 4
    (1323.0, 1024.0), # P4 5
    (189.0, 128.0),   # TT 6
    (3.0, 2.0),       # P5 7
    (49.0, 32.0),     # m6 8
    (7.0, 4.0),       # M6 9
    (441.0, 256.0),   # m7 10
    (63.0, 32.0),     # M7 11
)

LOUIS = (
    (1, 1), 
    (math.sqrt(5) * 0.5, 1),
    (math.sqrt(6) * 0.5, 1), 
    (math.sqrt(7) * 0.5, 1), 
    (math.sqrt(2), 1), 
    (math.sqrt(9) * 0.5, 1), 
    (math.sqrt(10) * 0.5, 1), 
    (math.sqrt(11) * 0.5, 1), 
    (math.sqrt(3), 1), 
    (math.sqrt(13) * 0.5, 1), 
    (math.sqrt(14) * 0.5, 1), 
    (math.sqrt(15) * 0.5, 1), 
)

# scale mappings
MAJOR = (0, 2, 4, 5, 7, 9, 11)
MINOR = (0, 2, 3, 5, 7, 8, 10)
CHROMATIC = tuple(range(12))

# notated as semitone deviations from 
# a MAJOR scale for readability
SCALES = {
    'MAJOR': MAJOR,
    'MINOR': MINOR,
    'super_locrian': (0, 2-1, 4-1, 5-1, 7-1, 9-1, 11-1),
    'neapolitan_minor': (0, 2-1, 4-1, 5, 7, 9-1, 11),
    'neapolitan_major': (0, 2-1, 4-1, 5, 7, 9, 11),
    'oriental': (0, 2-1, 4, 5, 7-1, 9, 11-1),
    'double_harmonic': (0, 2-1, 4, 5, 7, 9-1, 11),
    'enigmatic': (0, 2-1, 4, 5+1, 7+1, 9+1, 11),
}

cdef tuple DEFAULT_RATIOS = TERRY
DEFAULT_SCALE = MAJOR


def _int_to_byte_list(val):
    return list(map(int, list(bin(val))[2:]))

def _str_to_byte_list(val):
    return list(map(int, val))

def _to_scale_mask(mapping):
    mask = []
    if isinstance(mapping, int):
        mask = _int_to_byte_list(mapping)
    elif isinstance(mapping, bytes):
        for i in list(mapping):
            mask += _int_to_byte_list(i)
    elif isinstance(mapping, str):
        mask = _str_to_byte_list(mapping)
    elif isinstance(mapping, list) or isinstance(mapping, tuple):
        mask = list(map(int, mapping))
    else:
        raise NotImplemented

    return mask

def _scale_mask_to_indexes(mask):
    mask = _to_scale_mask(mask)
    scale_indexes = []
    for i, m in enumerate(mask):
        if m == 1:
            scale_indexes += [ i ]
    return scale_indexes

def fit_scale(freq, scale):
    # Thanks to @kennytm from stack overflow for this <3 <3
    return min(scale, key=lambda x:abs(x-freq))

def degrees(scale_degrees=None, octave=2, root=None, key=None, scale=None, ratios=None, scale_mask=None):
    if scale_degrees is None:
        scale_degrees = [1,3,5]

    if root is not None:
        print('WARNING: please use `key` rather than `root` to specify key')
        key = root

    if key is None:
        key = DEFAULT_KEY

    if ratios is None:
        ratios = DEFAULT_RATIOS

    if scale is None:
        scale = MAJOR

    if scale_mask is not None:
        scale = _scale_mask_to_indexes(scale_mask)

    freqs = []
    root = ntf(key, octave) # TODO: check for float to allow arbitrary roots?

    for index, degree in enumerate(scale_degrees):
        # strings are okay
        degree = int(degree)

        # register offset 0+
        register = degree // (len(scale) + 1)

        chromatic_degree = scale[(degree - 1) % len(scale)]
        ratio = ratios[chromatic_degree]
        freqs += [ root * (ratio[0] / ratio[1]) * 2**register ]

    return freqs

def edo(degree, divs=12):
    return 2**(degree/float(divs))

def edo_ratios(divs=12):
    return [ (edo(i, divs), 1.0) for i in range(1, divs+1) ]

def edo_scale(divs=12):
    return [ edo(i, divs) for i in range(1, divs+1) ]


