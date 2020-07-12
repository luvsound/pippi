import random
from unittest import TestCase

from pippi.oscs import Osc, Osc2d, Pulsar, Pulsar2d, Alias, Bar, Tukey
from pippi.soundbuffer import SoundBuffer
from pippi.wavesets import Waveset
from pippi import dsp, fx, tune, shapes

class TestOscs(TestCase):
    def test_create_sinewave(self):
        osc = Osc('sine', freq=200.0)
        length = 1
        out = osc.play(length)
        out.write('tests/renders/osc_sinewave.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

        wtA = [ random.random() for _ in range(random.randint(10, 1000)) ]
        osc = Osc(wtA, freq=200.0)
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_rand_list_wt.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

        wtB = dsp.wt([ random.random() for _ in range(random.randint(10, 1000)) ])
        osc = Osc(wtB, freq=200.0)
        length = 1
        out = osc.play(length)
        out.write('tests/renders/osc_rand_wt_wt.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

        wtC = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        osc = Osc(wtC, freq=200.0)
        length = 1
        out = osc.play(length)
        out.write('tests/renders/osc_guitar_wt.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_create_wt_stack(self):
        wtA = [ random.random() for _ in range(random.randint(10, 1000)) ]
        wtB = dsp.wt([ random.random() for _ in range(random.randint(10, 1000)) ])
        wtC = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        stack = ['rnd', wtA, wtB, wtC] * 10
        osc = Osc2d(stack, freq=200.0)
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc2d_RND_randlist_randwt_guitar_10x.wav')

        self.assertEqual(len(out), int(length * out.samplerate))

    def test_create_tukey(self):
        osc = Tukey()
        length = 10
        shape = dsp.win(shapes.win('sine', length=3), 0, 0.5)
        chord = tune.chord('i9', octave=2)
        out = dsp.buffer(length=length)
        for freq in chord:
            freq = dsp.wt('sinc', freq, freq*4)
            l = osc.play(length, freq, shape)
            l = l.pan(dsp.rand())
            out.dub(l)
        out = fx.norm(out, 0.8)
        out.write('tests/renders/osc_tukey.wav')

    def test_create_pulsar(self):
        osc = Pulsar(
                'sine', 
                window='sine', 
                pulsewidth=dsp.wt('tri', 0, 1), 
                freq=200.0, 
                amp=0.2
            )
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_pulsar.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_pulsar_burst(self):
        osc = Pulsar(
                'sine', 
                window='sine', 
                pulsewidth=dsp.wt('tri', 0, 1), 
                burst=(3,2),
                freq=200.0, 
                amp=0.2
            )
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_pulsar_burst.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_pulsar_mask(self):
        osc = Pulsar(
                'sine', 
                window='sine', 
                pulsewidth=dsp.wt('tri', 0, 1), 
                mask=dsp.wt('phasor', 0, 1), 
                freq=200.0, 
                amp=0.2
            )
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_pulsar_mask.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_pulsar_burst_and_mask(self):
        osc = Pulsar(
                'sine', 
                window='sine', 
                pulsewidth=dsp.wt('tri', 0, 1), 
                mask=dsp.randline(30, 0, 1), 
                burst=(3,2),
                freq=200.0, 
                amp=0.2
            )
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_pulsar_burst_and_mask.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_create_pulsar2d(self):
        osc = Pulsar2d(
                ['sine', 'square', 'tri', 'sine'], 
                windows=['sine', 'tri', 'hann'], 
                wt_mod=dsp.wt('saw', 0, 1), 
                win_mod=dsp.wt('rsaw', 0, 1), 
                pulsewidth=dsp.wt('tri', 0, 1), 
                freq=200.0, 
                amp=0.2
            )
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_pulsar2d.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_waveset_pulsar2d(self):
        rain = dsp.read('tests/sounds/rain.wav').cut(0, 1)
        ws = Waveset(rain)
        ws.normalize()
        osc = Pulsar2d(ws,
                windows=['sine'], 
                freq=200.0, 
                amp=0.2
            )
        out = osc.play(10)
        out.write('tests/renders/osc_waveset_pulsar2d.wav')

    def test_create_alias(self):
        osc = Alias(freq=200.0)
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_alias.wav')
        self.assertEqual(len(out), int(length * out.samplerate))

    def test_create_bar(self):
        length = 1
        out = dsp.buffer(length=length)

        params = [(0.21, 1, 0), (0.3, 0.9, 0.5), (0.22, 0.8, 1)]

        for beat, inc, pan in params:
            pos = 0
            stiffness = 280
            while pos < length:
                duration = dsp.rand(1, 4)
                decay = dsp.rand(0.1, 10)
                velocity = dsp.rand(500, 2000)
                barpos = dsp.rand(0.2, 0.8)
                width = dsp.rand(0.1, 0.8)
                stiffness = max(1, stiffness)

                note = Bar(decay=decay, stiffness=stiffness, velocity=velocity, barpos=barpos, width=width).play(duration).env('hannout').pan(pan)
                out.dub(note, pos)
                pos += beat
                stiffness -= inc

        out = fx.norm(out, 1)

        out.write('tests/renders/osc_bar.wav')

