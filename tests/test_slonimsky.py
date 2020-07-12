from unittest import TestCase
from pippi import slonimsky, dsp, tune, soundfont, fx, shapes

class TestSlonimsky(TestCase):
    def test_principle_tones(self):
        note = 110
        intervals = range(1, 12)

        events = []
        pos = 0
        voice = 1

        for interval in intervals:
            scale = slonimsky.principle_tones(interval)
            freqs = [ ((deg+12)//12, tune.JUST[deg % 12]) for deg in scale ]
            freqs = [ (r[1][0] / r[1][1]) * r[0] * note for r in freqs ]

            for freq in freqs:
                events += [dict(
                    start=pos, 
                    length=0.5, 
                    freq=freq,
                    amp=dsp.rand(0.5, 0.55), 
                    voice=voice,
                )]

                pos += 0.2

        out = soundfont.playall("tests/sounds/florestan-gm.sf2", events)
        out = fx.norm(out, 0.75)
        out.write('tests/renders/slonimsky_intervals-1-12-principle-scales.wav')


