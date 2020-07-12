from unittest import TestCase
from pippi import dsp, fft, fx, shapes

class TestFFT(TestCase):
    def test_fft_convolve_real(self):
        g = dsp.read('tests/sounds/guitar1s.wav')
        l = dsp.read('tests/sounds/LittleTikes-B1.wav')

        out = g.convolve(l)
        out.write('tests/renders/fft_conv.wav')


    def test_fft_transform(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        snd2 = dsp.read('tests/sounds/LittleTikes-B1.wav').cut(0, 1)
        mod = dsp.buffer(dsp.win('sine', wtsize=len(snd))).remix(1).remix(2)

        # Transform
        real1, imag1 = fft.transform(snd)
        real2, imag2 = fft.transform(snd2)

        # Do stuff
        imag = real1 * real2
        real = imag1 * imag2

        mag, arg = fft.to_polar(real, imag)

        #mag = fx.lpf(mag, 100)
        real, imag = fft.to_xy(mag, arg)

        # Inverse Transform
        out = fft.itransform(real, imag)
        out = fx.norm(out, 1)
        out.write('tests/renders/fft_transform.wav')


    def test_fft_process(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        length = 2

        def cb(pos, real, imag):
            mag, arg = fft.to_polar(real, imag)
            mag = fx.lpf(mag, pos * 5000 + 100)
            return fft.to_xy(mag, arg)
           
        bs = dsp.win(shapes.win('sine'), 0.05, 0.3)
        out = fft.process(snd, bs, length, callback=cb)
        out = fx.norm(out, 1)
        out.write('tests/renders/fft_process.wav')
