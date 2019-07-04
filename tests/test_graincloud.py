from os import path
import random
import shutil
import tempfile
from unittest import TestCase

from pippi.soundbuffer import SoundBuffer
from pippi import dsp, grains

class TestCloud(TestCase):
    def setUp(self):
        self.soundfiles = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.soundfiles)

    def test_unmodulated_graincloud(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        cloud = grains.Cloud(sound)

        length = random.triangular(1, 4)
        framelength = int(length * sound.samplerate)

        out = cloud.play(length)
        self.assertEqual(len(out), framelength)

        out.write('tests/renders/graincloud_unmodulated.wav')

    def test_pulsed_graincloud(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        out = sound.cloud(10, grainlength=0.06, grid=0.12)
        out.write('tests/renders/graincloud_pulsed.wav')

    def test_long_graincloud(self):
        sound = SoundBuffer(filename='tests/sounds/linux.wav')
        length = 90
        grainlength = dsp.win('hann', 0.01, 0.08)
        grid = dsp.win('hann', 0.01, 0.05)

        out = sound.cloud(length, 
                grainlength=grainlength,
                grid=grid,
                spread=0.5,
        )

        framelength = int(length * sound.samplerate)
        self.assertEqual(len(out), framelength)

        out.write('tests/renders/graincloud_long.wav')

    def test_graincloud_with_length_lfo(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        grainlength = dsp.wt('hann', 0.01, 0.1)
        length = 10
        framelength = int(length * sound.samplerate)

        out = sound.cloud(length, grainlength=grainlength)

        self.assertEqual(len(out), framelength)

        out.write('tests/renders/graincloud_with_length_lfo.wav')

    def test_graincloud_with_speed_lfo(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        minspeed = random.triangular(0.05, 1)
        maxspeed = minspeed + random.triangular(0.5, 10)
        speed = dsp.wt('rnd', minspeed, maxspeed)
        cloud = grains.Cloud(sound, grainlength=0.04, speed=speed)

        length = 30
        framelength = int(length * sound.samplerate)

        out = cloud.play(length)
        self.assertEqual(len(out), framelength)

        out.write('tests/renders/graincloud_with_speed_lfo.wav')

    def test_graincloud_with_extreme_speed_lfo(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        length = 30
        speed = dsp.wt('hann', 1, 100)
        framelength = int(length * sound.samplerate)

        out = sound.cloud(length=length, speed=speed)
        self.assertEqual(len(out), framelength)

        out.write('tests/renders/graincloud_with_extreme_speed_lfo.wav')

    def test_graincloud_with_read_lfo(self):
        sound = SoundBuffer(filename='tests/sounds/linux.wav')
        cloud = grains.Cloud(sound, position=dsp.win('hann', 0, 1))

        length = 30
        framelength = int(length * sound.samplerate)

        out = cloud.play(length)
        self.assertEqual(len(out), framelength)

        out.write('tests/renders/graincloud_with_read_lfo.wav')

