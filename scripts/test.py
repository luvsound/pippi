from pippi.soundbuffer import SoundBuffer
from pippi import wavetables
from pippi.wavetables import Wavetable
from pippi import dsp


import numpy as np
import os

wt_size = 4096
sine = Wavetable(wavetables.to_wavetable('sine'), wtsize=wt_size, bl_quality = 6)

sr = 96000
time = 4
length = sr * time
render1 = np.zeros((length, 2), dtype='d')
render2 = np.zeros((length, 2), dtype='d')

sweep = np.logspace(0, 9, length, base = 2) * 30
sweep /= sr
phase = 0

for i in range(0, length):
    inc = sweep[i]
    phase += inc
    if phase >= 1:
        phase -= 1
    sample1 = sine.interp(phase, method='hermite')
    sample2 = sine.bli_pos(phase, inc)
    render1[i][0] = sample1
    render1[i][1] = sample2

out = SoundBuffer(render1, samplerate=sr)
square = Wavetable(wavetables.to_wavetable('square'), wtsize=wt_size, bl_quality = 8)

for i in range(0, length):
    inc = sweep[i]
    phase += inc
    if phase >= 1:
        phase -= 1
    sample1 = square.interp(phase, method='linear')
    sample2 = square.bli_pos(phase, inc)
    render2[i][0] = sample1
    render2[i][1] = sample2

out += SoundBuffer(render2, samplerate=sr)

out.write('scripts/renders/wavetables_bl_sweep.wav')

os.system('sox scripts/renders/wavetables_bl_sweep.wav -n spectrogram -o scripts/renders/wavetables_bl_sweep.png')
os.system('open scripts/renders/wavetables_bl_sweep.png')
os.system('afplay scripts/renders/wavetables_bl_sweep.wav')
