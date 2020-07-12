from unittest import TestCase
from pippi import dsp, shapes, oscs

class TestShapes(TestCase):
    def test_shape_wt(self):
        dsp.seed()
        wt = shapes.wt('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
        amp = shapes.wt('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
        wt = wt * amp
        wt.graph('tests/renders/shape_wt.png')

    def test_shape_win(self):
        dsp.seed()
        wt = shapes.win('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
        amp = shapes.win('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
        wt = wt * amp
        wt.graph('tests/renders/shape_win.png')

    def test_shape_synth(self):
        dsp.seed()
        out = shapes.synth('sine', minfreq=80, maxfreq=800, stability=0.99, length=10)
        amp = shapes.win('sine', length=10)
        out = out * amp
        out.write('tests/renders/shape_synth.wav')

    def test_shape_pulsar(self):
        dsp.seed()

        wts = [ shapes.wt('sine', length=1) for _ in range(3) ]
        wins = [ shapes.win('sine', length=1) for _ in range(3) ]
        wins = [ w * dsp.win('hann') for w in wins ]
        amp = shapes.win('sine', length=1)
        pw = dsp.win(shapes.win('sine', length=1), 0.1, 1)
        freq = dsp.win(shapes.win('sine', length=1), 20, 260)
        grid = dsp.win(shapes.win('sine', length=1), 0.001, 0.75)
        gl = dsp.win(shapes.win('sine', length=1), 0.03, 0.3)
        win = shapes.win('sine', length=1) * dsp.win('hann')
        out = oscs.Pulsar2d(wts, 
                windows=wins,
                freq=freq,
                pulsewidth=pw,
                amp=amp,
            ).play(1).cloud(
                length=10, 
                window=win, 
                grainlength=gl, 
                grid=grid, 
                speed=dsp.win(shapes.win('sine', length=1), 0.03, 2),
                spread='rnd', 
                jitter='rnd'
            )

        out.write('tests/renders/shape_pulsar.wav')

