#!/usr/bin/env python2.7
# -*- coding: UTF-8 -*-

""" Anti-copywrite. Do whatever you would like with this software.
"""

import wave
import audioop
import math
import struct
import time
import os
import sys
import collections

try:
    from _pippic import amp
    from _pippic import am
    from _pippic import add
    from _pippic import subtract
    from _pippic import mul
    from _pippic import invert
    from _pippic import mix
    from _pippic import pine
    from _pippic import synth
    from _pippic import curve
    from _pippic import pulsar
    from _pippic import fold
    from _pippic import tone as wtone
    from _pippic import cycle as ccycle

except ImportError:
    print 'Warning: could not import C dsp extensions'

from _pippicython import env

SAMPLING_RATE = 44100
BIT_DEPTH = 16
BIT_WIDTH = 2
CHANNELS = 2
WINDOW_SIZE = 64

# Deprecated params
bitdepth = 16
dsp_grain = 64
audio_params = [2, 2, 44100, 0, "NONE", "not_compressed"]
quiet = True 
# End deprecated params

from pippi.timers import delay
from pippi.timers import monotonic

##############
# List helpers
##############

from pippi.lists import interleave
from pippi.lists import packet_shuffle
from pippi.lists import list_split
from pippi.lists import rotate
from pippi.lists import eu


##############
# Utils
##############

from pippi.utils import log
from pippi.utils import flen
from pippi.utils import byte_string
from pippi.utils import pack
from pippi.utils import unpack
from pippi.utils import scale
from pippi.utils import cap
from pippi.utils import timestamp_filename
from pippi.utils import timer
from pippi.utils import flatten


###############
# Units
###############

from pippi.units import stf
from pippi.units import mstf
from pippi.units import ftms
from pippi.units import fts
from pippi.units import ftc
from pippi.units import fth
from pippi.units import htf
from pippi.units import bpm2ms
from pippi.units import bpm2frames


###############
# Random
###############

from pippi.rand import seed
from pippi.rand import stepseed
from pippi.rand import randint
from pippi.rand import rand
from pippi.rand import randchoose
from pippi.rand import randbool
from pippi.rand import randshuffle


###############
# FX
###############

from pippi.fx import stretch
from pippi.fx import alias


###############
# DSP
###############

def bln(length, low=3000.0, high=7100.0, wform='sine2pi'):
    """ Time-domain band-limited (citation needed) noise generator.

        Generates a series of single cycles of a given wavetype 
        at random frequences within the supplied range.
        
        Sounds nice & warm, if you ask me.
    """
    outlen = 0
    cycles = ''
    while outlen < length:
        acycle = cycle(rand(low, high), wform)
        outlen += len(acycle)
        cycles += acycle

    return cycles

def reverse(snd):
    return audioop.reverse(snd, BIT_WIDTH)

def avg(snd):
    return audioop.avg(snd, BIT_WIDTH)

def max(snd):
    return audioop.max(snd, BIT_WIDTH)

def transpose(snd, amount, chans=None):
    """ Change the speed of a sound.
        1.0 is unchanged, 0.5 is half speed, 2.0 is twice speed, etc.
        
        This is a wrapper for audioop.ratecv in the standard library."""
    if chans is None:
        chans = CHANNELS

    amount = 1.0 / float(amount)
    rate = int(SAMPLING_RATE * amount)
    return audioop.ratecv(snd, BIT_WIDTH, chans, SAMPLING_RATE, rate, None)[0]

def tone(length=44100, freq=440.0, wavetype='sine', amp=1.0, phase=0.0, offset=0.0):
    """ 
        Synthesize a tone with the given params.

        Possible wavetypes:

        * sine2pi or sine
        * cos2pi or cos
        * hann
        * tri
        * saw or line
        * isaw or phasor
        * vary
        * impulse
        * square

        Length is given in frames.
    """
    # Quick and dirty mapping to transition to the new api
    if wavetype == 'sine2pi' or wavetype == 'sine':
        wtype = 0
    elif wavetype == 'cos2pi' or wavetype == 'cos':
        wtype = 1
    elif wavetype == 'hann':
        wtype = 2
    elif wavetype == 'tri':
        wtype = 3
    elif wavetype == 'saw' or wavetype == 'line':
        wtype = 4
    elif wavetype == 'isaw' or wavetype == 'phasor':
        wtype = 5
    elif wavetype == 'vary':
        wtype = 6
    elif wavetype == 'impulse':
        wtype = 7
    elif wavetype == 'square':
        wtype = 8
    else:
        wtype = 0

    return synth(wtype, float(freq), length, amp, phase, offset)
        
def noise(length):
    return ''.join([byte_string(randint(-32768, 32767)) for i in range(length * audio_params[0])])

def cycle(freq, wavetype='sine2pi', amp=1.0):
    #wavecycle = wavetable(wavetype, htf(freq))
    # Quick and dirty mapping to transition to the new api
    if wavetype == 'sine2pi' or wavetype == 'sine':
        wtype = 0
    elif wavetype == 'cos2pi' or wavetype == 'cos':
        wtype = 1
    elif wavetype == 'hann':
        wtype = 2
    elif wavetype == 'tri':
        wtype = 3
    elif wavetype == 'saw' or wavetype == 'line':
        wtype = 4
    elif wavetype == 'isaw' or wavetype == 'phasor':
        wtype = 5
    elif wavetype == 'vary':
        wtype = 6
    elif wavetype == 'impulse':
        wtype = 7
    elif wavetype == 'square':
        wtype = 8

    #return ''.join([pack(amp * s) * audio_params[0] for s in wavecycle])
    return ccycle(wtype, htf(freq), 1.0, amp)

def fill(string, length, chans=2, silence=False):
    if flen(string) < length:
        if silence == False:
            try:
                repeats = length / flen(string) + 1
            except ZeroDivisionError:
                return string
        else:
            return pad(string, 0, length - flen(string))

        string = string * repeats

    return cut(string, 0, length)

def pad(string, start, end):
    # start and end given in samples, as usual 
    # eg lengths of silence to pad at start and end

    zero = struct.pack('<h', 0)
    zero = zero[0:1] * audio_params[1] * audio_params[0] # will we ever have a width > 2? donno.

    return "%s%s%s" % ((start * zero), string, (end * zero))

def iscrossing(first, second):
    """ Detects zero crossing between two mono frames """

    if len(first) == 2 and len(second) == 2:
        first = struct.unpack("<h", first) 
        second = struct.unpack("<h", second) 

        if first[0] > 0 and second[0] < 0:
            return True
        elif first[0] < 0 and second[0] > 0:
            return True
        elif first[0] == 0 and second[0] != 0:
            return False 
        elif first[0] != 0 and second[0] == 0:
            return True 

    return False

def insert_into(haystack, needle, position):
    # split string at position index
    hay = cut(haystack, 0, position)
    stack = cut(haystack, position, flen(haystack) - position)
    return "%s%s%s" % (hay, needle, stack)

def replace_into(haystack, needle, position):
    hayend = position * audio_params[1] * audio_params[0]
    stackstart = hayend - (flen(needle) * audio_params[1] * audio_params[0])
    return "%s%s%s" % (haystack[:hayend], needle, haystack[stackstart:])

def cut(snd, start, length):
    # start and length are both given in frames (aka samples)za

    #if start + length > flen(string):
        #log('No cut for you!')
        #log('in len: '+str(flen(string))+'start: '+str(start)+' length: '+str(length))

    length = int(length) * audio_params[1] * audio_params[0]
    start = int(start) * audio_params[1] * audio_params[0]

    return snd[start : start + length]

def rcut(snd, length):
    """ Cut a segment of a given length from a random position in the given sound. """
    return cut(snd, randint(0, flen(snd) - length), length)

def splitmono(snd):
    """ split a stereo sound into a list of mono sounds """
    left = audioop.tomono(snd, audio_params[1], 1, 0)
    right = audioop.tomono(snd, audio_params[1], 0, 1)

    return [left, right] 

def tomono(snd):
    return splitmono(snd)

def stereo(snd):
    """ Just a wrapper for audioop.tostereo from the standard library. 
        Pass it a mono sound and it will convert it to stereo.
    """
    return audioop.tostereo(snd, audio_params[1], 0.5, 0.5)

def split(string, size, chans=2):
    """ split a sound into chunks of size N in frames, or by zero crossings """
    if size == 0:
        if chans == 2:
            # split into mono files
            tracks = splitmono(string)

            for i, track in enumerate(tracks):
                tracks[i] = split(track, 0, 1)

            return tracks

        elif chans == 1:
            frames = split(string, 1, 1)
            chunk, chunks = [], []

            for i, frame in enumerate(frames):
                try:
                    if chunk == []:
                        chunk += [ frame ]
                    elif iscrossing(frame, frames[i+1]) == False and chunk != []:
                        chunk += [ frame ]
                    elif iscrossing(frame, frames[i+1]) == True and chunk != []:
                        chunk += [ frame ]
                        chunks += [ ''.join(chunk) ]
                        chunk = []
                except IndexError:
                    chunk += [ frame ]
                    chunks += [ ''.join(chunk) ]

            return chunks

    elif size > 0:
        frames = int(size) * audio_params[1] * chans 
        return [string[frames * count : (frames * count) + frames] for count in range(len(string) / frames)]

def vsplit(input, minsize, maxsize):
    # min/max size is in frames...
    output = []
    pos = 0

    for chunk in range(flen(input) / minsize):
        chunksize = randint(minsize, maxsize)
        if pos + chunksize < flen(input) - chunksize:
            output.append(cut(input, pos, chunksize))
            pos += chunksize

    return output

def write(audio_string, filename, timestamp=False, cwd=True, channels=2):
    """ Write audio data to renders directory with the Python wave module """
    if timestamp == True:
        filename = filename + '-' + timestamp_filename() + '.wav' 
    else:
        filename = filename + '.wav'

    if cwd:
        filename = os.getcwd() + '/' + filename

    wavfile = wave.open(filename, "w")
    wavfile.setparams(audio_params)
    wavfile.setnchannels(channels)
    wavfile.writeframes(audio_string)
    wavfile.close()
    return filename

def cache(s='', clear=False):
    """ Simple write() wrapper to create and clear cache audio """
    if clear == True:
        files = os.listdir('renders/cache/')
        for file in files:
            os.remove('renders/cache/' + file)
    else:
        return write(s, 'cache/c', True)

    return s 

def read(filename):
    """ Read a 44.1k / 16bit WAV file from disk with the Python wave module. 
        Mono files are converted to stereo automatically. """
    if not quiet: print 'loading', filename

    file = wave.open(filename, "r")
    file_frames = file.readframes(file.getnframes())

    snd = Sound()

    # check for mono files
    if file.getnchannels() == 1:
        file_frames = audioop.tostereo(file_frames, file.getsampwidth(), 0.5, 0.5)
        snd.params = file.getparams()
        snd.params = (2, snd.params[1], snd.params[2], snd.params[3], snd.params[4], snd.params[5])
    else:
        snd.params = file.getparams()

    snd.data = file_frames

    return snd

def pantamp(pan_pos):
    # Translate the pan position into a tuple size two of left amp and right amp
    if pan_pos > 0.5:
        pan_pos -= 0.5
        pan_pos *= 2.0
        pan_pos = 1.0 - pan_pos
        pan_pos = (pan_pos, 1.0)
    elif pan_pos < 0.5:
        pan_pos *= 2.0
        pan_pos = (1.0, pan_pos)
    else:
        pan_pos = (1.0, 1.0)

    return pan_pos

def pan(slice, pan_pos=0.5, amp=1.0):
    amps = pantamp(pan_pos)

    lslice = audioop.tomono(slice, audio_params[1], 1, 0)
    lslice = audioop.tostereo(lslice, audio_params[1], amps[0], 0)

    rslice = audioop.tomono(slice, audio_params[1], 0, 1)
    rslice = audioop.tostereo(rslice, audio_params[1], 0, amps[1])

    slice = audioop.add(lslice, rslice, audio_params[1])
    return audioop.mul(slice, audio_params[1], amp)

def benv(sound, points):
    chunksize = mstf(3)
    sounds = split(sound, chunksize)
    points = breakpoint(points, len(sounds))

    return ''.join([amp(s, points[i]) for i, s in enumerate(sounds)])
 
def panenv(sound, ptype='line', etype='sine', panlow=0.0, panhigh=1.0, envlow=0.0, envhigh=1.0):
    packets = split(sound, WINDOW_SIZE)

    ptable = wavetable(ptype, len(packets), panlow, panhigh)
    etable = wavetable(etype, len(packets), envlow, envhigh)

    packets = [pan(p, ptable[i], etable[i]) for i, p in enumerate(packets)]

    return ''.join(packets)

def drift(sound, amount, size=441):
    high = (amount * 0.5) + 1.0
    low = 1.0 - (amount * 0.5)
    sound = split(sound, 441)
    freqs = wavetable('sine', len(sound), high, low)
    sound = [ transpose(sound[i], freqs[i]) for i in range(len(sound)) ]

    return ''.join(sound)

def fnoise(sound, coverage):
    target_frames = int(flen(sound) * coverage)

    for i in range(target_frames):
        p = randint(0, flen(sound) - 1)
        f = cut(sound, p, 1)
        sound = replace_into(sound, f, randint(0, flen(sound) - 1))

    return sound

def crosstwo(a, b, length):
    length = mstf(length)

    out = ''

    out += cut(a, 0, flen(a) - length)

    fadeout = cut(a, flen(a) - length, length)
    fadeout = env(fadeout, 'phasor')

    fadein = cut(b, 0, length)
    fadein = env(fadein, 'line')

    out += mix([ fadein, fadeout ])

    out += cut(b, length, flen(b) - length)

    return out

def cross(snds, length, maxlen=None):
    out = ''
    for i, snd in enumerate(snds):
        fadelen = length if maxlen is None else rand(length, maxlen)

        if i == 0:
            out = crosstwo(snds[i], snds[i+1], fadelen)
        elif i < len(snds) - 1:
            try:
                out = crosstwo(out, snds[i+1], fadelen)
            except IndexError:
                return out

    return out

def adsr(snd, a=10, d=50, s=1.0, r=100):
    sndlen = flen(snd)
    attack = mstf(a)
    decay = mstf(d)
    sustain_to = s
    release = mstf(r)

    if attack + decay + release > sndlen:
        sustain_length = sndlen - (attack + decay + release)
    else:
        sustain_length = 0
        decay = sndlen - (attack + release)

    if attack + release > sndlen:
        attack = sndlen / 2
        release = sndlen / 2
        decay = 0

    out = env(cut(snd, 0, attack), 'line')
   
    if decay > 0:
        decay = cut(snd, flen(out), decay)
        if sustain_to < 1 and sustain_length > 0:
            decaytable = wavetable('phasor', 1024, 1, sustain_to)
            out += benv(decay, decaytable)
            out += amp(cut(snd, flen(out), sustain_length), sustain_to)

    out += env(cut(snd, flen(out), release), 'phasor')

    return out

def taper(snd, amount=441):
    first = cut(snd, 0, amount)
    first = env(first, 'line')

    middle = cut(snd, amount, flen(snd) - (amount * 2))

    last = cut(snd, flen(first) + flen(middle), amount)
    last = env(last, 'phasor')

    return '%s%s%s' % (first, middle, last)





####################
# Periodic functions
####################

def breakpoint(values, size=512):
    """ Takes a list of values, or a pair of wavetable types and values, 
    and builds an interpolated list of points between each value using 
    the wavetable type. Default table type is linear. """

    # we need at least a start and end point
    if len(values) < 2:
        values = [ 0.0, ['line', 1.0] ] 

    # Handle some small size cases
    if size == 0:
        #log('WARNING: breakpoint size 0')
        #log('values: '+str(values))
        #log('')
        return []
    elif size < 4 and size > 0:
        #log('WARNING: small breakpoint, size ' + str(size))
        #log('values: '+str(values))
        #log('')
        return [values[0] for i in range(size)]

    # Need at least one destination value per point computed
    if size < len(values):
        values = values[:size]

    # Each value produces a group of intermediate points
    groups = []

    # The size of each group of intermediate points is divded evenly into the target 
    # size, ignoring the first value and accounting for uneven divisions.
    gsize = size / (len(values)-1) 
    gsizespill = size % (len(values)-1)

    # Pretend the first loop shifts the last endval to the startval
    try:
        if len(values[0]) > 1:
            endval = values[0][1]
    except TypeError:
        endval = values[0]
    values.pop(0)

    # To build the list of points, loop through each value
    for i, v in enumerate(values):
        try:
            if len(v) > 1:
                wtype = v[0]
                startval = endval 
                endval = v[1]

            if len(v) == 3:
                gsize = gsize * v[2]
        except TypeError:
            wtype = 'line'
            startval = endval
            endval = v

        # Pad last group with leftover points
        if v == values[-1]:
            gsize += gsizespill 

        groups.extend(wavetable(wtype, gsize, endval, startval))

    return groups

def wavetable(wtype="sine", size=512, highval=1.0, lowval=0.0):
    """ The end is near. That'll do, wavetable()
    """
    wtable = []
    wave_types = ["sine", "gauss", "cos", "line", "saw", "impulse", "phasor", "sine2pi", "cos2pi", "vary", "flat"]

    if wtype == "random":
        wtype = wave_types[int(rand(0, len(wave_types) - 1))]

    if wtype == "sine":
        wtable = [math.sin(i * math.pi) * (highval - lowval) + lowval for i in frange(size, 1.0, 0.0)]

    elif wtype == "hann" or wtype == "hanning":
        wtable = [ 0.5 * ( 1 - math.cos((2 * math.pi * i) / (size - 1))) for i in range(size) ]

    elif wtype == "gauss":
        def gauss(x):
            # From: http://johndcook.com/python_phi.html
            # Prolly doing it wrong!
            a1 =  0.254829592
            a2 = -0.284496736
            a3 =  1.421413741
            a4 = -1.453152027
            a5 =  1.061405429
            p  =  0.3275911

            sign = 1
            if x < 0:
                sign = -1
            x = abs(x)/math.sqrt(2.0)

            t = 1.0/(1.0 + p * x)
            y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)

            return abs(abs(sign * y) - 1.0)

        wtable = [gauss(i) * (highval - lowval) + lowval for i in frange(size, 2.0, -2.0)] 
    elif wtype == "sine2pi":
        wtable = [math.sin(i * math.pi * 2) * (highval - lowval) + lowval for i in frange(size, 1.0, 0.0)]

    elif wtype == "cos2pi":
        wtable = [math.cos(i * math.pi * 2) * (highval - lowval) + lowval for i in frange(size, 1.0, 0.0)]

    elif wtype == "cos":
        wtable = [math.cos(i * math.pi) * (highval - lowval) + lowval for i in frange(size, 1.0, 0.0)]

    elif wtype == "itri":
        # Inverted triangle
        wtable = [math.fabs(i) for i in frange(size, highval, lowval - highval)] # Only really a triangle wave when centered on zero 

    elif wtype == "tri":
        wtable = [ (2.0 / (size + 1)) * ((size + 1) / 2.0 - math.fabs(i - ((size - 1) / 2.0))) for i in range(size) ]

    elif wtype == "saw" or wtype == "line":
        wtable = [i for i in frange(size, highval, lowval)]

    elif wtype == "phasor":
        wtable = wavetable("line", size, highval, lowval)
        list.reverse(wtable)

    elif wtype == "impulse":
        wtable = [float(randint(-1, 1)) for i in range(size / randint(2, 12))]
        wtable.extend([0.0 for i in range(size - len(wtable))])

    elif wtype == "vary":
        if size < 32:
            bsize = size
        else:
            bsize = size / int(rand(2, 16))

        btable = [ [wave_types[int(rand(0, len(wave_types)-1))], rand(lowval, highval)] for i in range(bsize) ]

        if len(btable) > 0:
            btable[0] = lowval
        else:
            btable = [lowval]

        wtable = breakpoint(btable, size) 
    elif wtype == "flat":
        wtable = [highval for i in range(size)]
    
    return wtable

def frange(steps, highval=1.0, lowval=0.0):
    if steps == 1:
        return [lowval]

    return  [ (i / float(steps-1)) * (highval - lowval) + lowval for i in range(steps)]

def prob(item_dictionary):
    weighted_list = []
    for item, weight in item_dictionary.iteritems():
        for i in range(weight):
            weighted_list.append(item)

    return randchoose(weighted_list)

def logistic(r=3.8, x=0.5, numpoints=500):
    vals = []
    for i in range(numpoints):
        x = r * x * (1.0 - x)
        vals += [ x ]

    return vals








###########
# Misc
###########

def ddelay(frames):
    target = (frames / 44100.0) + time.time()

    time.sleep(fts(frames))

    while target > time.time():
        time.sleep(target - time.time())

    return True





class Sound(collections.MutableSequence):
    def __init__(self, data='', channels=2, depth=16, rate=44100):
        super(Sound, self).__init__()

        self.data = data
        self.channels = channels
        self.depth = depth
        self.rate = rate

    def __len__(self):
        return flen(self.data)

    def __str__(self):
        return self.data

    def __contains__(self, key):
        """ TODO: search by frame or group of frames """
        return False

    def __getitem__(self, index):
        return cut(self.data, index, 1)

    def __setitem__(self, index, value):
        replace_into(self.data, value, index)

    def __delitem__(self, value):
        """ TODO: delete frames by value... """
        pass

    def insert(self, index, value):
        insert_into(self.data, value, index)

    def append(self, value):
        if isinstance(value, Sound) or isinstance(value, list):
            self.frames += [ value ]
        else:
            print 'foo'

    def loop(self, loops):
        self.data = self.data * loops

    def __iadd(self, value):
        return self.__add__(value)

    def __add__(self, value):
        if isinstance(value, int):
            return value
        elif isinstance(value, Sound):
            return Sound(mix([self.data, value.data]))

    def __radd__(self, value):
        return self.__add__(value)

    def __sub__(self, value):
        if isinstance(value, int):
            return Sound([ frame - int(value) for frame in self.frames ])
        elif isinstance(value, Sound):
            return Sound([ frame - value[i] for i, frame in enumerate(self.frames) ])
    
    def __rsub__(self, value):
        if isinstance(value, int):
            return Sound([ int(value) - frame for frame in self.frames ])
        elif isinstance(value, Sound):
            return Sound([ value[i] - frame for i, frame in enumerate(self.frames) ])

    def __mul__(self, value):
        if isinstance(value, int) or isinstance(value, float):
            return Sound([ frame * value for frame in self.frames ])
        elif isinstance(value, Sound):
            return Sound([ frame * value[i] for i, frame in enumerate(self.frames) ])

    def __rmul__(self, value):
        return self.__mul__(value)

    def unpack(self, value=None):
        value = self.data if value is None else value

        return [ struct.unpack('<h', '%s%s' % (frame, value[i]))[0]  for i, frame in enumerate(value) if i % 2 == 0 and i < len(value) - 1 ] 

