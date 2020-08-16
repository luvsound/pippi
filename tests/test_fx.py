from unittest import TestCase
from pippi import dsp, interpolation, wavetables, fx, oscs, noise
import numpy as np
import random

class TestFx(TestCase):
    def test_vspeed(self):
        g = dsp.read('tests/sounds/guitar10s.wav')
        lfo = dsp.win('sine', 4096)
        snd = fx.vspeed(g, lfo, 0.5, 1)
        snd = fx.norm(snd, 1)
        g = dsp.read('tests/sounds/guitar10s.wav')
        snd = snd + g
        snd.write('tests/renders/fx_vspeed.wav')

    def test_convolve(self):
        sound = dsp.read('tests/sounds/guitar1s.wav')
        impulse = dsp.read('tests/sounds/LittleTikes-A1.wav')

        out = fx.convolve(sound, impulse)
        out.write('tests/renders/fx_convolve_guitar_littletikes.wav')

        impulse = dsp.win('sinc')
        out = fx.convolve(sound, impulse)
        out.write('tests/renders/fx_convolve_guitar_sinc.wav')

    def test_tconvolve(self):
        sound = dsp.read('tests/sounds/guitar1s.wav')
        impulse = dsp.win('sinc')

        out = fx.tconvolve(sound, impulse)
        out.write('tests/renders/fx_tconvolve_guitar_sinc.wav')

    def test_wconvolve(self):
        sound = dsp.read('tests/sounds/guitar10s.wav')
        impulse = dsp.read('tests/sounds/LittleTikes-A1.wav')

        out = fx.wconvolve(sound, impulse)
        out.write('tests/renders/fx_wconvolve_guitar_littletikes-0.02.wav')

        """
        # these operations are really slow, so disable them for most test runs
        out = fx.wconvolve(sound, impulse, 'hann')
        out.write('tests/renders/fx_wconvolve_guitar_littletikes-hann.wav')

        out = fx.wconvolve(sound, impulse, 'sinc')
        out.write('tests/renders/fx_wconvolve_guitar_littletikes-sinc.wav')

        out = fx.wconvolve(sound, impulse, dsp.win('hann', 0.01, 0.5))
        out.write('tests/renders/fx_wconvolve_guitar_littletikes-hann-0.01-0.5.wav')

        out = fx.wconvolve(sound, impulse, grid='hann')
        out.write('tests/renders/fx_wconvolve_guitar_littletikes-grid-hann.wav')
        """


    def test_crossfade(self):
        snd1 = dsp.read('tests/sounds/linux.wav').cut(0, 3)
        snd2 = dsp.read('tests/sounds/guitar10s.wav').cut(0, 3)
        out = fx.crossfade(snd1, snd2, 'saw')
        out.write('tests/renders/fx_crossfade.wav')

    def test_envelope_follower(self):
        snd = dsp.read('tests/sounds/linux.wav')
        osc = oscs.Osc('sine')
        carrier = osc.play(snd.dur)
        out = carrier * snd.toenv()
        out.write('tests/renders/fx_envelope_follower.wav')

    def test_widen(self):
        snd = dsp.read('tests/sounds/linux.wav')
        out = fx.widen(snd, dsp.win('phasor', 0, 1))
        out.write('tests/renders/fx_widen_linux.wav')

        osc = oscs.Osc('sine', amp=0.2)
        out = osc.play(snd.dur)
        out = fx.widen(out, dsp.win('phasor', 0, 1))
        out.write('tests/renders/fx_widen_sine.wav')

    def test_crush(self):
        snd = dsp.read('tests/sounds/linux.wav')
        out = fx.crush(snd)
        out.write('tests/renders/fx_crush_linux.wav')

        snd = dsp.read('tests/sounds/guitar10s.wav')
        out = fx.crush(snd)
        out.write('tests/renders/fx_crush_guitar.wav')

        out = fx.crush(snd, dsp.win('sine', 2, 16), 44100)
        out.write('tests/renders/fx_crush_guitar_vbitdepth.wav')

        out = fx.crush(snd, 16, dsp.win('sine', 200, 44100))
        out.write('tests/renders/fx_crush_guitar_vsamplerate.wav')

        out = fx.crush(snd, dsp.win('hannin', 2, 16), dsp.win('sine', 200, 44100))
        out.write('tests/renders/fx_crush_guitar_vboth.wav')


    def test_crossover(self):
        snd = dsp.read('tests/sounds/linux.wav')
        amount = dsp.win('phasor', 0, 1)
        smooth = 0.3
        fade = dsp.win('rsaw', 0, 1)
        out = fx.crossover(snd, amount, smooth, fade)
        out.write('tests/renders/fx_crossover_linux.wav')

        osc = oscs.Osc('sine', amp=0.2)
        out = osc.play(snd.dur)
        out = fx.crossover(out, amount, smooth, fade)
        out.write('tests/renders/fx_crossover_sine.wav')

    def test_delay(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        snd = fx.delay(snd, 1, 0.5)
        snd = fx.norm(snd, 1)
        snd.write('tests/renders/fx_delay.wav')

    def test_vdelay(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        tlfo = dsp.randline(3, 30, 0, 1)
        lfo = dsp.randline(30, 4096, 0, 1)
        snd = fx.vdelay(snd, lfo, 0.1, 0.75, 0.5)
        snd = fx.norm(snd, 1)
        snd.write('tests/renders/fx_vdelay.wav')

    def test_mdelay(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        ndelays = 20
        snd = fx.mdelay(snd, [ random.triangular(0, 8) for _ in range(ndelays) ], 0.7)
        snd = fx.norm(snd, 1)
        snd.write('tests/renders/fx_mdelay.wav')

    def test_compressor(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        ratio = 4
        threshold = -10
        attack = 0.2
        release = 0.2

        out = fx.compressor(snd, ratio, threshold, attack, release)
        out.write('tests/renders/fx_compressor.wav')

    def test_paulstretch(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        stretch = 30

        out = fx.paulstretch(snd, stretch)
        out.write('tests/renders/fx_paulstretch.wav')

    def test_mincer(self):
        snd = dsp.read('tests/sounds/linux.wav')
        length = 20
        position = dsp.randline(10, 0.5, 2)
        pitch = dsp.randline(10)

        out = fx.mincer(snd, length, position, pitch)
        out.write('tests/renders/fx_mincer.wav')

    def test_saturator_nodc(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        drive = 10
        dcoffset = 0
        dcblock = False

        out = fx.saturator(snd, drive, dcoffset, dcblock)
        out = fx.norm(out, 1)
        out.write('tests/renders/fx_saturator_nodc.wav')

    def test_saturator_dc(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        drive = 10
        dcoffset = 0.1
        dcblock = True

        out = fx.saturator(snd, drive, dcoffset, dcblock)
        out.write('tests/renders/fx_saturator_dc.wav')

    def test_buttlp(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 100

        out = fx.buttlpf(snd, freq)
        out.write('tests/renders/fx_buttlpf.wav')

    def test_butthp(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 1000

        out = fx.butthpf(snd, freq)
        out.write('tests/renders/fx_butthpf.wav')

    def test_buttbp(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 500

        out = fx.buttbpf(snd, freq)
        out.write('tests/renders/fx_buttbpf.wav')

    def test_buttbr(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 500

        out = fx.brf(snd, freq)
        out.write('tests/renders/fx_buttbrf.wav')

    def test_softclip(self):
        out = oscs.SineOsc(freq=[30, 10000], amp=10).play(1).softclip()
        out.write('tests/renders/fx_softclip.wav')

    def test_svf_lp(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        res = 0
        out = fx.lpf(snd, freq, res)
        out.write('tests/renders/fx_svf_lp-r0.wav')

        freq = [20, 10000]
        res = 1
        out = fx.lpf(snd, freq, res)
        out.write('tests/renders/fx_svf_lp-r1.wav')

    def test_svf_hp(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        res = 0
        out = fx.hpf(snd, freq, res)
        out.write('tests/renders/fx_svf_hp-r0.wav')

        freq = [20, 10000]
        res = 1
        out = fx.hpf(snd, freq, res)
        out.write('tests/renders/fx_svf_hp-r1.wav')

    def test_svf_bp(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        res = 0
        out = fx.bpf(snd, freq, res)
        out.write('tests/renders/fx_svf_bp-r0.wav')

        freq = [20, 10000]
        res = 1
        out = fx.bpf(snd, freq, res)
        out.write('tests/renders/fx_svf_bp-r1.wav')

    def test_svf_notchf(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        res = 0
        out = fx.notchf(snd, freq, res)
        out.write('tests/renders/fx_svf_notchf-r0.wav')

        freq = [20, 10000]
        res = .5
        out = fx.notchf(snd, freq, res)
        out.write('tests/renders/fx_svf_notchf-r1.wav')

    def test_svf_peakf(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        res = .5
        out = fx.peakf(snd, freq, res)
        out.write('tests/renders/fx_svf_peakf-r0.wav')

        freq = [20, 10000]
        res = 1
        out = fx.peakf(snd, freq, res)
        out.write('tests/renders/fx_svf_peakf-r1.wav')

    def test_svf_belleq(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        q = .5
        gain = -30
        out = fx.belleq(snd, freq, q, gain)
        out.write('tests/renders/fx_svf_belleq-q0.wav')

        freq = 600
        q = .5
        gain = [-30, 30]
        out = fx.belleq(snd, freq, q, gain)
        out.write('tests/renders/fx_svf_belleq-q1.wav')

    def test_svf_hshelfeq(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        q = .5
        gain = -30
        out = fx.belleq(snd, freq, q, gain)
        out.write('tests/renders/fx_svf_hshelfeq-q0.wav')

        freq = 600
        q = .5
        gain = [-30, 30]
        out = fx.belleq(snd, freq, q, gain)
        out.write('tests/renders/fx_svf_hshelfeq-q1.wav')

    def test_svf_lshelfeq(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freq = [20, 10000]
        q = .5
        gain = -30
        out = fx.belleq(snd, freq, q, gain)
        out.write('tests/renders/fx_svf_lshelfeq-q0.wav')

        freq = 440
        q = 8
        gain = [-30, 30]
        out = fx.belleq(snd, freq, q, gain)
        out.write('tests/renders/fx_svf_lshelfeq-q1.wav')

    def test_svf_stereo(self):
        snd = dsp.read('tests/sounds/whitenoise10s.wav')
        freql = [20, 10000]
        freqr = [10000, 20]
        res = [0, 1]
        out = fx.bpf(snd, [freql, freqr], res)
        out.write('tests/renders/fx_svf_st-r0.wav')

        freq = [20, 10000]
        resl = "sine"
        resr = "cos"
        out = fx.bpf(snd, freq, [resl, resr])
        out.write('tests/renders/fx_svf_st-r1.wav')

    def test_fold(self):
        amp = dsp.win('hannin', 1, 10)

        snd = dsp.read('tests/sounds/guitar1s.wav')
        out = fx.fold(snd, amp)
        out.write('tests/renders/fx_fold_guitar.wav')

        snd = oscs.Osc('sine', freq=200).play(1)
        out = fx.fold(snd, amp)
        out.write('tests/renders/fx_fold_sine.wav')

    def test_ms(self):

        snd = dsp.read('tests/sounds/guitar1s.wav')
        ms = fx.ms_encode(snd)
        lr = fx.ms_decode(ms)
        lr.write('tests/renders/fx_ms_parity.wav')

        snd1 = oscs.Osc('sine', freq=200).play(1).pan(0)
        snd2 = oscs.Osc('tri', freq=201).play(1).pan(1)
        out = fx.ms_decode(snd1 & snd2)
        out.write('tests/renders/fx_ms_detune.wav')

               
