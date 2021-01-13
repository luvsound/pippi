from unittest import TestCase
from pippi import dsp, fx, mir

class TestMIR(TestCase):
    def test_pitch(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        wt = mir.pitch(snd, tolerance=0.8)
        wt.graph('tests/renders/mir_pitch.png')
        print('maxfreq', max(wt), 'minfreq', min(wt))

    def test_onsets(self):
        snd = dsp.read('tests/sounds/rain.wav')

        onsets = mir.onsets(snd, 'specflux')
        self.assertEqual(len(onsets), 7)

        onsets = mir.onsets(snd, 'specflux', seconds=False)
        print(onsets)
        self.assertEqual(len(onsets), 7)

        segments = mir.segments(snd, 'specflux')
        self.assertEqual(len(segments), 7)

        out = dsp.buffer(length=7)
        pos = 0
        count = 1
        for segment in segments:
            segment = fx.norm(segment.env('pluckout').taper(0.05), 1)
            segment.write('tests/renders/mir_segment%02d.wav' % count)
            out.dub(segment, pos)
            pos += 1
            count += 1
        out.write('tests/renders/mir_segments.wav')

    def test_features(self):
        snd = dsp.read('tests/sounds/linux.wav')

        wt = mir.bandwidth(snd)
        wt.graph('tests/renders/mir_feature_bandwidth.png')

        wt = mir.flatness(snd)
        wt.graph('tests/renders/mir_feature_flatness.png')

        wt = mir.rolloff(snd)
        wt.graph('tests/renders/mir_feature_rolloff.png')

        wt = mir.centroid(snd)
        wt.graph('tests/renders/mir_feature_centroid.png')

        wt = mir.contrast(snd)
        wt.graph('tests/renders/mir_feature_contrast.png')


