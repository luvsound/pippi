import tempfile
import random
import re

from unittest import TestCase
from pippi import wavetables, dsp
from pippi.soundbuffer import SoundBuffer
from pippi.wavetables import Wavetable
from pippi.oscs import Osc
import numpy as np

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

    def test_save_and_load_wt(self):
        wt = dsp.wt('sine', wtsize=4096)
        self.assertEqual(len(wt), 4096)
        wt.write('tests/renders/wavetable_sine.wav')
        wt.graph('tests/renders/wavetable_sine-original.png')

        wt = dsp.load('tests/renders/wavetable_sine.wav')
        wt.graph('tests/renders/wavetable_sine-reloaded.png')

    def test_cut(self):
        wt = dsp.wt('sine', wtsize=4092)
        wt.graph('tests/renders/wavetable_precut.png')
        wt = wt.cut(10, 100)
        wt.graph('tests/renders/wavetable_cut.png')
        self.assertEqual(100, len(wt.data))

    def test_rcut(self):
        wt = dsp.wt('sine', wtsize=4092)
        wt.graph('tests/renders/wavetable_prercut.png')
        wt = wt.rcut(100)
        wt.graph('tests/renders/wavetable_rcut.png')
        self.assertEqual(100, len(wt))

    def test_rcut_bad(self):
        wt = dsp.wt('sine', wtsize=4092)
        wt = wt.rcut(-100)
        self.assertEqual(1, len(wt))

    def test_cut_bad(self):
        wt = dsp.wt('sine', wtsize=4092)
        wt = wt.cut(-100, -100)
        self.assertEqual(1, len(wt))

    def test_randline(self):
        numpoints = 3
        wtsize = 10

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

    def test_graph_pluckin_window(self):
        wt = dsp.win('pluckin')
        wt.graph('tests/renders/graph_pluckin_window.png', stroke=3)

    def test_graph_pluckout_window(self):
        wt = dsp.win('pluckout')
        wt.graph('tests/renders/graph_pluckout_window.png', stroke=3)

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

    def test_pong(self):
        win = dsp.win('hann', 0, 0.75).harmonics().skewed(0.08).rightpadded(0, mult=4)
        win = win + dsp.win('hannout', 0, 0.25, wtsize=len(win))
        win.graph('tests/renders/graph_pong.png', stroke=3)

    def test_mix_wavetables(self):
        win = dsp.win([1,2,3])
        self.assertEqual(len(win), 3)
        self.assertEqual(win & dsp.win([2,2,2]), dsp.win([3,4,5]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(win & dsp.win([1,3,5]), dsp.win([2,5,8]))
        self.assertEqual(win, dsp.win([1,2,3]))

    def test_mul_wavetables(self):
        win = dsp.win([1,2,3])
        self.assertEqual(len(win), 3)
        self.assertEqual(win * 2, dsp.win([2,4,6]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(win * dsp.win([1,3,5]), dsp.win([1,6,15]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(dsp.win([1,3,5]) * win, dsp.win([1,6,15]))
        self.assertEqual(win, dsp.win([1,2,3]))

        with self.assertRaises(TypeError):
            2 * win
        self.assertEqual(win, dsp.win([1,2,3]))

    def test_add_wavetables(self):
        win = dsp.win([1,2,3])
        self.assertEqual(len(win), 3)
        self.assertEqual(win + 2, dsp.win([1,2,3,2]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(win + dsp.win([1,3,5]), dsp.win([1,2,3,1,3,5]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(dsp.win([1,3,5]) + win, dsp.win([1,3,5,1,2,3]))
        self.assertEqual(win, dsp.win([1,2,3]))

        with self.assertRaises(TypeError):
            2 + win
        self.assertEqual(win, dsp.win([1,2,3]))

    def test_sub_wavetables(self):
        win = dsp.win([1,2,3])
        self.assertEqual(len(win), 3)
        self.assertEqual(win - 2, dsp.win([-1,0,1]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(win - dsp.win([1,3,5]), dsp.win([0,-1,-2]))
        self.assertEqual(win, dsp.win([1,2,3]))

        self.assertEqual(dsp.win([1,3,5]) - win, dsp.win([0,1,2]))
        self.assertEqual(win, dsp.win([1,2,3]))

        with self.assertRaises(TypeError):
            2 - win
        self.assertEqual(win, dsp.win([1,2,3]))

    wt_size = 4096

    def test_bandlimiting(self):
        # filler
        wt_size = 4096
        sine = Wavetable(wavetables.to_wavetable('sine'), wtsize=wt_size, bl_quality = 3)

        sr = 96000
        time = 4
        length = sr * time
        render1 = np.zeros((length, 2), dtype='d')
        render2 = np.zeros((length, 2), dtype='d')

        sweep = np.logspace(0, 9, length, base = 2) * 30
        sweep /= sr
        phase = 0

        for i in range(0, length):
            inc = sweep[i]
            phase += inc
            if phase >= 1:
                phase -= 1
            sample1 = sine.interp(phase, method='linear')
            sample2 = sine.bli_pos(phase, inc)
            render1[i][0] = sample1
            render1[i][1] = sample2

        out = SoundBuffer(render1, samplerate=sr)
        square = Wavetable(wavetables.to_wavetable('square'), wtsize=wt_size, bl_quality = 8)

        for i in range(0, length):
            inc = sweep[i]
            phase += inc
            if phase >= 1:
                phase -= 1
            sample1 = square.interp(phase, method='linear')
            sample2 = square.bli_pos(phase, inc)
            render2[i][0] = sample1
            render2[i][1] = sample2

        out += SoundBuffer(render2, samplerate=sr)

        out.write('tests/renders/wavetable_bl_sweep.wav')

