from unittest import TestCase
from pippi import dsp, multiband, fx
import numpy as np
import random

class TestMultibadn(TestCase):
    def test_split(self):
        g = dsp.read('tests/sounds/guitar10s.wav')
        bands = multiband.split(g, 1000)
        for i, b in enumerate(bands):
            b.write('tests/renders/multiband_split-band%s.wav' % i)

        out = dsp.mix(bands)
        out = fx.norm(out, 1)
        out.write('tests/renders/multiband_split-reconstruct.wav')

