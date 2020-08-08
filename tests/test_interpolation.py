from unittest import TestCase
from pippi import interpolation
import numpy as np
import random

class TestInterpolation(TestCase):
    def test_interpolate_linear(self):
        for _ in range(10):
            wtsize = random.randint(1, 100)
            npoints = random.randint(2, 100) 
            wt = np.array([ random.random() for _ in range(wtsize) ], dtype='d')

            points = []
            for i in range(npoints):
                points += [ interpolation.linear_pos(wt, i/npoints) ]

            lpoints = [ p for p in interpolation.linear(wt, npoints) ]

            self.assertEqual(points, lpoints)

    def test_interpolate_bandlimit(self):
        wt_size = 4096

        tabletest = Bandlimit(wavetable='square', quality = 5)

        sr = 44100
        time = 4
        length = sr * time

        render = np.zeros((length, 2), dtype='d')

        phase = 0
        sweep = np.logspace(0, 5, length, base = 2)
        sweep /= sr
        sweep *= wt_size

        native_inc = wt_size/sr

        for i in range(0, length):
            inc = native_inc * sweep[i]
            resample = 1/(wt_size*inc)
            if resample > 1:
                resample = 1
            sample = tabletest.process(phase, resample)
            render[i][0] = sample
            render[i][1] = sample
            phase += inc
            if phase >= 1:
                phase -= 1

        out = SoundBuffer(render)

        out.write('tests/renders/bltest.wav')

