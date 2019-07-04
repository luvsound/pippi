from unittest import TestCase
from pippi import dsp, shapes, oscs

class TestShapes(TestCase):
    def test_shape_wt(self):
        dsp.seed()
        for i in range(4):
            wt = shapes.wt('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
            amp = shapes.wt('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
            wt = wt * amp
            wt.graph('tests/renders/shape_wt%s.png' % i, width=1024)

    def test_shape_win(self):
        dsp.seed()
        for i in range(4):
            wt = shapes.win('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
            amp = shapes.win('sine', length=10, density='rnd', stability='rnd', periodicity='rnd')
            wt = wt * amp
            wt.graph('tests/renders/shape_win%s.png' % i, width=1024)

    def test_shape_synth(self):
        dsp.seed()
        for i in range(4):
            out = shapes.synth('sine', minfreq=80, maxfreq=800, stability=0.99, length=10)
            amp = shapes.win('sine', length=10)
            out = out * amp
            out.write('tests/renders/shape_synth%s.wav' % i)

    def test_shape_pulsar(self):
        dsp.seed()
        for i in range(4):
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
                ).play(dsp.rand(0.2, 1)).cloud(
                    length=20, 
                    window=win, 
                    grainlength=gl, 
                    grid=grid, 
                    speed=dsp.win(shapes.win('sine', length=1), 0.03, 2),
                    spread='rnd', 
                    jitter='rnd'
                )

            out.write('tests/renders/shape_pulsar%s.wav' % i)

