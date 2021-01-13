from unittest import TestCase
from pippi import dsp, multiband, fx
import numpy as np
import random

class TestMultiband(TestCase):
    def test_split(self):
        g = dsp.read('tests/sounds/guitar1s.wav')
        bands = multiband.split(g, 3)
        for i, b in enumerate(bands):
            b.write('tests/renders/multiband_split-band%02d.wav' % i)
        out = dsp.mix(bands)
        out = fx.norm(out, 1)
        out.write('tests/renders/multiband_split-reconstruct.wav')

    def test_split_and_drift(self):
        g = dsp.read('tests/sounds/guitar1s.wav')
        bands = multiband.split(g, 3, 'hann', 100)
        for i, b in enumerate(bands):
            b.write('tests/renders/multiband_split-drift-band%02d.wav' % i)
        out = dsp.mix(bands)
        out = fx.norm(out, 1)
        out.write('tests/renders/multiband_split-drift-reconstruct.wav')

    def test_customsplit(self):
        g = dsp.read('tests/sounds/guitar1s.wav')
        freqs = [400, 3000, 3005, 10000]
        bands = multiband.customsplit(g, freqs)
        for i, b in enumerate(bands):
            b.write('tests/renders/multiband_customsplit-band%02d.wav' % i)
        out = dsp.mix(bands)
        out = fx.norm(out, 1)
        out.write('tests/renders/multiband_customsplit-reconstruct.wav')

    def test_spread(self):
        dsp.seed()
        g = dsp.read('tests/sounds/guitar1s.wav')
        out = multiband.spread(g)
        out.write('tests/renders/multiband_spread-guitar-0.5.wav')

        """
        dsp.seed()
        g = dsp.read('tests/sounds/living.wav')
        out = multiband.spread(g)
        out.write('tests/renders/multiband_spread-living-0.5.wav')
        """


    def test_smear(self):
        dsp.seed()
        g = dsp.read('tests/sounds/guitar10s.wav').rcut(1)
        out = multiband.smear(g)
        out.write('tests/renders/multiband_smear-guitar-0.01.wav')

        dsp.seed()
        g = dsp.read('tests/sounds/living.wav')
        out = multiband.smear(g)
        out.write('tests/renders/multiband_smear-living-0.01.wav')


