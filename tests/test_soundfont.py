from unittest import TestCase
from pippi import dsp, soundfont, fx

dsp.seed()

class TestSoundfont(TestCase):
    def test_play(self):
        length = 3
        freq = 660
        amp = 1
        voice = 1
        out = soundfont.play("tests/sounds/florestan-gm.sf2", length, freq, amp, voice)
        out.write('tests/renders/soundfont_play.wav')

    def test_playall(self):
        events = []
        pos = 0
        length = 10

        while pos < length:
            events += [(pos, dsp.rand(0.2, 3), 110*dsp.randint(1, 10), dsp.rand(), dsp.randint(0, 127))]
            pos += dsp.rand(0.01, 0.2)
 
        out = soundfont.playall("tests/sounds/florestan-gm.sf2", events)
        out = fx.norm(out, 0.5)
        out.write('tests/renders/soundfont_playall.wav')


