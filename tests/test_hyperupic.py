from unittest import TestCase
from pippi import dsp, hyperupic, oscs, tune

class TestHyperUPIC(TestCase):
    def test_get_partials_from_image(self):
        partials = hyperupic.partials('tests/images/louis.jpg', 4)

        for i, p in enumerate(partials):
            for j, c in enumerate(p):
                c.graph('tests/renders/hyperupic-partial-%02d-%02d.png' % (i, j), y=(0,1))

    def test_render_image(self):
        length = 10
        degrees = list(range(1,10))
        freqs = tune.degrees(degrees, octave=2)

        #out = hyperupic.sineosc('tests/images/louis.jpg', freqs, length) * 0.6
        #out.write('tests/renders/hyperupic-sineosc-render.wav')

        #snd = dsp.read('tests/sounds/living.wav')
        #out = hyperupic.bandpass('tests/images/louis.jpg', freqs, snd)
        #out.write('tests/renders/hyperupic-bandpass-render.wav')

        snd = dsp.read('tests/sounds/guitar1s.wav')
        out = hyperupic.pulsar('tests/images/louis.jpg', freqs, snd, length)
        out.write('tests/renders/hyperupic-pulsar-render.wav')

