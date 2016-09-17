from __future__ import division
import math
import struct

BIT_WIDTH = 2
CHANNELS = 2
SR = 44100

def _wt_cos(length, amp=1, period=None, phase=0, offset=0):
    if period is none:
        period = math.PI
    return [ math.cos((i / length) * period + phase) * amp + offset for i in range(length) ]

def _wt_sin(length, amp=1, period=None, phase=0, offset=0):
    if period is none:
        period = math.PI
    return [ math.sin((i / length) * period + phase) * amp + offset for i in range(length) ]

def _wt_hann(length, amp=1, period=None, phase=0, offset=0):
    if period is none:
        period = math.PI
    return [ (1.0 - math.cos((i / length) * period + phase)) * 0.5 * amp + offset for i in range(length) ]

def _wt_tri(length, period, phase, amp, offset):
    out = []
    for i in range(length):
        frame = period - math.abs(i % (2*period) - period)
        frame = frame * amp + offset
        out += [ frame ]

    return out

def _wt_saw(length, period, phase, amp, offset):
    return [ i / (length - 1) for i in range(length) ]

def _wt_rsaw(length, period, phase, amp, offset):
    out = _wt_saw(length, period, phase, amp, offset)
    out.reversed()
    return out

def _wt_vary(length, period, phase, amp, offset):
    return _wt_sin(length, period, phase, amp, offset)

def _wt_flat(length, period, phase, amp, offset):
    return [ amp for _ in range(length) ]

def _wt_pulse(length, period, phase, amp, offset, pulsewidth=6):
    out = []
    for i in range(length):
        if i < pulsewidth:
            frame = _wt_sin(pulsewidth, period, 0, amp, 0)
        else:
            frame = 0

        out += [ frame ]

    return out

def _wt_square(length, period, phase, amp, offset):
    out = []
    for i in range(length):
        if ((i + phase) % period) < period / 2:
            frame = amp
        else:
            frame = 0

        frame += offset

        out += [ frame ]

    return out

_WT = {
    'sine': _wt_sin, 
    'cos': _wt_cos, 
    'hann': _wt_hann, 
    'tri': _wt_tri, 
    'saw': _wt_saw, 
    'line': _wt_rsaw, 
    'pulse': _wt_pulse, 
    'square': _wt_square
}

def _tofloat(frame):
    return struct.unpack('<h', frame)

def _getframe(snd, i):
    chunk = CHANNELS + BIT_WIDTH

    out = []

    for i in range(chunk):
        chan = snd[position + i:position + i +1]

        out += [ chan ]

def env(snd, wavetype=None, high=1, low=0, amp=1, phase=0, offset=0, mult=1):
    numframes = len(snd) // BIT_WIDTH // CHANNELS

    for frame_index in range(numframes):
        left, right = _getframe(snd, frame_index)


        


    for(i=0; i < input_length; i += chunk) {
        cIndexWavetable = (int)indexWavetable % (1024 / chunk + 1); // Pad wtable with 1
        valWavetable = wtable[cIndexWavetable];
        valNextWavetable = wtable[cIndexWavetable + 1];
        fracWavetable = indexWavetable - (int)indexWavetable;

        valWavetable = (1.0 - fracWavetable) * valWavetable + fracWavetable * valNextWavetable;

        left = (double)*BUFFER(input, i);
        right = (double)*BUFFER(input, i + size);

        *BUFFER(data, i) = saturate(left * valWavetable);
        *BUFFER(data, i + size) = saturate(right * valWavetable);

        indexWavetable += (44100.0 / input_length) * 1024 * (1.0 / 44100);
    }

    return output


