from pippi.soundbuffer import SoundBuffer
from pippi import wavetables
from pippi.wavetables import Wavetable
from pippi import dsp

import numpy as np
import os

from tkinter import filedialog

path = filedialog.askopenfilename()
print(path)

out = dsp.read(path)
out = out.cloud(10, grainlength=dsp.win('sine', .1, .01), grid=dsp.win('line', .1, .01))

out_path = 'scripts/renders/explore'
out.write(out_path+'.wav')

os.system('sox '+out_path+'.wav -n spectrogram -o '+out_path+'.png')
os.system('open '+out_path+'.png')
os.system('afplay '+out_path+'.wav')