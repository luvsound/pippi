from unittest import TestCase
from pippi import dsp

class TestFFT(TestCase):
    def test_fft_convolve_real(self):
        g = dsp.read('tests/sounds/guitar1s.wav')
        l = dsp.read('tests/sounds/LittleTikes-B1.wav')

        out = g.convolve(l)
        out.write('tests/renders/fft_conv.wav')


