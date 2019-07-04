import tempfile
import random
import re

from unittest import TestCase
from pippi import wavetables, dsp
from pippi.oscs import Osc

class TestWavetables(TestCase):
    def test_random_window(self):
        length = random.randint(1, 1000)
        win = dsp.win('rnd', wtsize=length)
        self.assertEqual(length, len(win))

    def test_random_wavetable(self):
        length = random.randint(1, 1000)
        wt = dsp.wt('rnd', wtsize=length)
        self.assertEqual(length, len(wt))

    def test_wtclass(self):
        wt1 = dsp.wt('rnd', wtsize=4096)
        wt2 = dsp.wt('tri', wtsize=4096)
        wt3 = dsp.wt([ random.random()+0.001 for _ in range(1000) ], wtsize=1000)

        self.assertTrue(max(wt1) > 0)
        self.assertTrue(max(wt2) > 0)
        self.assertTrue(max(wt3) > 0)
        self.assertEqual(len(wt1), 4096)
        self.assertEqual(len(wt2), 4096)
        self.assertEqual(len(wt3), 1000)

    """
    def test_polyseg(self):
        score = 'sine 1,tri,0-1 rand,0.3-0.8'
        length = random.randint(100, 1000)
        for segment in score.split(' '):
            match = wavetables.SEGMENT_RE.match(segment)

     
        wt = wavetables.polyseg(score, length)

        self.assertEqual(len(wt), length)
    """

    def test_randline(self):
        numpoints = random.randint(1, 10)
        wtsize = random.randint(10, 1000)

        wt = dsp.randline(numpoints, wtsize=wtsize)
        self.assertEqual(len(wt), wtsize)

        lowvalue = random.triangular(0, 1)
        highvalue = random.triangular(1, 5)
        wt = dsp.randline(numpoints, 
                            lowvalue=lowvalue, 
                            highvalue=highvalue, 
                            wtsize=wtsize
                        )

        self.assertEqual(len(wt), wtsize)
        self.assertTrue(max(wt) <= highvalue)
        self.assertTrue(min(wt) >= lowvalue)

    def test_graph_sine_wavetable(self):
        wt = dsp.wt('sine')
        wt.graph('tests/renders/graph_sine_wavetable.png', stroke=3)

    def test_graph_cos_wavetable(self):
        wt = dsp.wt('cos')
        wt.graph('tests/renders/graph_cos_wavetable.png', stroke=3)

    def test_graph_tri_wavetable(self):
        wt = dsp.wt('tri')
        wt.graph('tests/renders/graph_tri_wavetable.png', stroke=3)

    def test_graph_saw_wavetable(self):
        wt = dsp.wt('saw')
        wt.graph('tests/renders/graph_saw_wavetable.png', stroke=3)

    def test_graph_rsaw_wavetable(self):
        wt = dsp.wt('rsaw')
        wt.graph('tests/renders/graph_rsaw_wavetable.png', stroke=3)

    def test_graph_square_wavetable(self):
        wt = dsp.wt('square')
        wt.graph('tests/renders/graph_square_wavetable.png', stroke=3)

    def test_graph_gauss_window(self):
        wt = dsp.win('gauss')
        wt.graph('tests/renders/graph_gauss_window.png', stroke=3)

    def test_graph_gaussin_window(self):
        wt = dsp.win('gaussin')
        wt.graph('tests/renders/graph_gaussin_window.png', stroke=3)

    def test_graph_gaussout_window(self):
        wt = dsp.win('gaussout')
        wt.graph('tests/renders/graph_gaussout_window.png', stroke=3)

    def test_graph_sinein_window(self):
        wt = dsp.win('sinein')
        wt.graph('tests/renders/graph_sinein_window.png', stroke=3)

    def test_graph_sineout_window(self):
        wt = dsp.win('sineout')
        wt.graph('tests/renders/graph_sineout_window.png', stroke=3)

    def test_graph_cos_window(self):
        wt = dsp.win('cos')
        wt.graph('tests/renders/graph_cos_window.png', stroke=3)

    def test_graph_tri_window(self):
        wt = dsp.win('tri')
        wt.graph('tests/renders/graph_tri_window.png', stroke=3)

    def test_graph_saw_window(self):
        wt = dsp.win('saw')
        wt.graph('tests/renders/graph_saw_window.png', stroke=3)

    def test_graph_rsaw_window(self):
        wt = dsp.win('rsaw')
        wt.graph('tests/renders/graph_rsaw_window.png', stroke=3)

    def test_graph_hann_window(self):
        wt = dsp.win('hann')
        wt.graph('tests/renders/graph_hann_window.png', stroke=3)

    def test_graph_hannin_window(self):
        wt = dsp.win('hannin')
        wt.graph('tests/renders/graph_hannin_window.png', stroke=3)

    def test_graph_hannout_window(self):
        wt = dsp.win('hannout')
        wt.graph('tests/renders/graph_hannout_window.png', stroke=3)

    def test_graph_hamm_window(self):
        wt = dsp.win('hamm')
        wt.graph('tests/renders/graph_hamm_window.png', stroke=3)

    def test_graph_black_window(self):
        wt = dsp.win('black')
        wt.graph('tests/renders/graph_black_window.png', stroke=3)

    def test_graph_bart_window(self):
        wt = dsp.win('bart')
        wt.graph('tests/renders/graph_bart_window.png', stroke=3)

    def test_graph_kaiser_window(self):
        wt = dsp.win('kaiser')
        wt.graph('tests/renders/graph_kaiser_window.png', stroke=3)

    def test_graph_sinc_window(self):
        wt = dsp.win('sinc')
        wt.graph('tests/renders/graph_sinc_window.png', stroke=3)

    def test_crushed(self):
        wt = dsp.win('sinc')
        wt.skew(0.65)
        wt.crush(10)
        wt.normalize(1)
        wt.graph('tests/renders/graph_skewed_crushed_normalized_sinc_window.png', stroke=3)

    def test_harmonics(self):
        wt = dsp.wt('sine')
        wt = wt.harmonics()
        wt.graph('tests/renders/graph_harmonics.png', stroke=3)
        osc = Osc(wt, freq=80)
        out = osc.play(10)
        out.write('tests/renders/osc_harmonics.wav')

    def test_seesaw(self):
        wt = wavetables.seesaw('tri', 4096, 0.85)
        wt.graph('tests/renders/graph_seesaw_tri.png', stroke=3)

        wt = wavetables.seesaw('sine', 4096, 0.85)
        wt.graph('tests/renders/graph_seesaw_sine.png', stroke=3)

    def test_insets(self):
        wt1 = wavetables.seesaw('rnd', 4096, dsp.rand(0, 1))
        wt1_graph = wt1.graph(stroke=10)

        wt2 = wavetables.seesaw('rnd', 4096, dsp.rand(0, 1))
        wt2_graph = wt2.graph(stroke=10)

        wt3 = wavetables.seesaw('rnd', 4096, dsp.rand(0, 1))
        wt3_graph = wt3.graph(stroke=10)

        snd = dsp.read('tests/sounds/linux.wav')
        snd.graph('tests/renders/graph_insets.png', insets=[wt1_graph, wt2_graph, wt3_graph], stroke=3, width=1200, height=500)

    def test_pong(self):
        win = dsp.win('hann', 0, 0.75).harmonics().skewed(0.08).rightpadded(0, mult=4)
        win = win + dsp.win('hannout', 0, 0.25, len(win))
        win.graph('tests/renders/graph_pong.png', stroke=3)


