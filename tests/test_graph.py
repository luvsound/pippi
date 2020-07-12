from unittest import TestCase
import shutil

from pippi import wavetables, dsp, graph, shapes, oscs, fx
from pippi.wavesets import Waveset

class TestGraph(TestCase):
    def test_insets(self):
        wt1 = wavetables.seesaw('rnd', 4096, dsp.rand(0, 1))
        wt1_graph = wt1.graph(label='LFO 1')

        wt2 = wavetables.seesaw('rnd', 4096, dsp.rand(0, 1))
        wt2_graph = wt2.graph(label='LFO 2')

        wt3 = wavetables.seesaw('rnd', 4096, dsp.rand(0, 1))
        wt3_graph = wt3.graph(label='LFO 3')

        snd = dsp.read('tests/sounds/linux.wav')
        snd.graph('tests/renders/graph_insets.png', insets=[wt1_graph, wt2_graph, wt3_graph], stroke=3, width=900, height=250, label='I pronounce Linux as Linux')

    def test_sandwich_board(self):
        l = dsp.read('tests/sounds/linux.wav')
        g = dsp.read('tests/sounds/guitar1s.wav')

        f = fx.crossover(l, dsp.win('phasor', 0, 1), dsp.rand(0.1, 0.3), dsp.win('rnd', 0, 1)).graph(fontsize=dsp.rand(60, 100), label='Weird FX')
        ws = Waveset(g).substitute('sine').graph(fontsize=dsp.rand(60, 100), label='Waveset Manipulation')
        ps = oscs.Pulsar2d(freq=dsp.rand(10,80), pulsewidth=shapes.win('hann')).play(2).graph(fontsize=dsp.rand(60,100), label='Pulsar Synthesis')

        wt = shapes.win('hann', length=0.4) * shapes.win('sine') * shapes.win('rnd')
        wt.graph('tests/renders/graph_sandwich_board.png', 
                insets=[ps, ws, f],
                width=900, 
                height=340, 
                label='Pippi: Computer Music With Python',
                stroke=30,
                fontsize=80,
            )

        # For the readme
        shutil.copy('tests/renders/graph_sandwich_board.png', 'banner.png')

    def test_range(self):
        wt = dsp.win('sine')
        wt.graph('tests/renders/graph_sine_range--1-1.png', y=(-1, 1))
        wt.graph('tests/renders/graph_sine_range--2-2.png', y=(-2, 2))
        wt.graph('tests/renders/graph_sine_range-0-1.png', y=(0, 1))
        wt.graph('tests/renders/graph_sine_range-0.5-2.png', y=(0.5, 2))

        wt = dsp.win('sinc')
        wt.graph('tests/renders/graph_sinc_range--0.2-1.png', y=(-0.25, 1))

    def test_labels(self):
        wt = dsp.win('sinc')
        wt.graph('tests/renders/graph_sinc_label.png', y=(-0.25, 1), label="Default label")
        wt.graph('tests/renders/graph_sinc_label_top.png', y=(-0.25, 1), label_top="Label top")
        wt.graph('tests/renders/graph_sinc_label_bottom.png', y=(-0.25, 1), label_bottom="Label bottom")
        wt.graph('tests/renders/graph_sinc_label_long.png', y=(-0.25, 1), label_bottom="A long bit of text & numbers 1,2,3")
