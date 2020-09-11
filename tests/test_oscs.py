import random
from unittest import TestCase

from pippi.oscs import Drunk, Fold, Osc, Osc2d, Pulsar, Pulsar2d, Alias, Bar, Tukey, DSS, FM, SineOsc
from pippi.soundbuffer import SoundBuffer
from pippi.wavesets import Waveset
from pippi import dsp, fx, tune, shapes

import numpy as np

class TestOscs(TestCase):
    def test_bandlimiting_osc(self):
        sr = 44100
        time = 4
        length = sr * time
        sweep = np.logspace(0, 9, length, base = 2) * 30
        out = Osc('tri', freq=sweep, quality=6).play(time)
        out.write('tests/renders/osc_bl.wav')

    def test_pm_osc(self):
        pmtest = Osc('sine', freq=[0, 800, 0], quality=6).play(1).env('tri')
        out = Osc('sine', freq=200, pm = pmtest, quality=6).play(1).env("tri")
        out.write('tests/renders/osc_pm.wav')

    def test_fm_osc(self):
        pm = Osc('sine', freq=200.0).play(1).env('tri') * 1000
        out = Osc('sine', freq=pm).play(1)
        out.write('tests/renders/osc_fm.wav')

        pm = Osc('sine', freq=[200.0, 300, 400], freq_interpolator='trunc').play(1).env('tri') * 1000
        out = Osc('sine', freq=pm).play(1)
        out.write('tests/renders/osc_fm_trunc.wav')

    def test_fold_osc(self):
        out = Fold('sine', freq=200, amp=[1,10]).play(1)
        out = fx.norm(out, 1)
        out.write('tests/renders/osc_fold.wav')

        out = Fold('sine', freq=[200, 300, 700, 900]*3, amp=[1,10], freq_interpolator='trunc').play(1)
        out = fx.norm(out, 1)
        out.write('tests/renders/osc_fold_trunc.wav')

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

    def test_create_drunk(self):
        out = Drunk(10, freq=200).play(10)
        out.write('tests/renders/osc_drunk-wdefault.wav')

        out = Drunk(10, width=dsp.win('hann', 0.01, 0.05), freq=200).play(10)
        out.write('tests/renders/osc_drunk-whann-0.01-0.05.wav')

        out = Drunk(10, 
            freq=[200,300,400,600]*8, 
            freq_interpolator='trunc'
        ).play(10)
        out.write('tests/renders/osc_drunk-trunc-freq.wav')

    def test_create_dss(self):
        out = DSS(10, ywidth=0.1, xwidth=0.001, freq=100).play(10)
        out.write('tests/renders/osc_dss-wdefault.wav')

        out = DSS(10, ywidth=dsp.win('hann', 0.01, 0.05), freq=200).play(10)
        out.write('tests/renders/osc_dss-whann-0.01-0.05.wav')

        out = DSS(10, ywidth=1, freq=200).play(10)
        out.write('tests/renders/osc_dss-w1.wav')

        out = DSS(10, freq=[200,300,150,1500], freq_interpolator='trunc').play(10)
        out.write('tests/renders/osc_dss-freq-trunc.wav')


    def test_create_fm(self):
        out = FM('sine', 'sine', freq=130.81, ratio=2.8, index=[6,0]).play(5).env('hannout') * 0.4
        out.write('tests/renders/osc_fm-basic.wav')

        out = FM('sine', 'sine', freq=[130.81, 300, 500], ratio=2.8, index=[6,0], freq_interpolator='trunc').play(5).env('hannout') * 0.4
        out.write('tests/renders/osc_fm-basic_trunc.wav')


    def test_create_sineosc(self):
        out = SineOsc(freq=130.81).play(5).env('hannout') * 0.25
        out.write('tests/renders/osc_sineosc-basic.wav')

    def test_create_osc2d(self):
        wtA = [ random.random() for _ in range(random.randint(10, 1000)) ]
        wtB = dsp.wt([ random.random() for _ in range(random.randint(10, 1000)) ])
        wtC = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        stack = ['rnd', wtA, wtB, wtC] * 10

        out = Osc2d(stack, freq=200.0).play(10)
        out.write('tests/renders/osc2d_RND_randlist_randwt_guitar_10x.wav')

        out = Osc2d(['tri', 'sine'], freq=[200.0, 400, 600], freq_interpolator='trunc').play(10)
        out.write('tests/renders/osc2d_freq_trunc.wav')

    def test_create_tukey(self):
        length = 10
        shape = dsp.win(shapes.win('sine', length=3), 0, 0.5)
        chord = tune.chord('i9', octave=2)
        out = dsp.buffer(length=length)
        for freq in chord:
            freq = dsp.wt('sinc', freq, freq*4)
            l = Tukey(freq=freq, shape=shape).play(length)
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

    def test_freq_interpolation_pulsar2d(self):
        freqs = tune.degrees([1,3,5,9,2,4,6,5,1], octave=3, key='a') * 10
        out = Pulsar2d(['sine', 'tri', 'square', 'hann'], ['hann'], 
            freq=freqs, 
            freq_interpolator='trunc',
            amp=0.2
        ).play(10)
        out.write('tests/renders/osc_pulsar2d_freq_trunc.wav')

    def test_create_alias(self):
        osc = Alias(freq=200.0)
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_alias.wav')

        osc = Alias(freq=[200, 300, 400, 600]*4, freq_interpolator='trunc')
        length = 10
        out = osc.play(length)
        out.write('tests/renders/osc_alias_trunc_freq.wav')

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

