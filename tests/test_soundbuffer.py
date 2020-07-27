from os import path
import random
import shutil
import tempfile
from unittest import TestCase

from pippi.soundbuffer import SoundBuffer
from pippi import dsp

class TestSoundBuffer(TestCase):
    def setUp(self):
        self.soundfiles = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.soundfiles)

    def test_create_empty_buffer(self):
        sound = SoundBuffer()
        self.assertTrue(len(sound) == 0)
        self.assertTrue(not sound)

        sound = SoundBuffer(length=1)
        self.assertEqual(len(sound), 44100)
        self.assertTrue(sound)

    def test_mix_operator(self):
        snd1 = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        snd2 = SoundBuffer(filename='tests/sounds/LittleTikes-A1.wav')

        snd1 &= snd2

        self.assertEqual(snd1.dur, snd2.dur)


    def test_create_stereo_buffer_from_soundfile(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        self.assertEqual(len(sound), 44100)
        self.assertTrue(sound.samplerate == 44100)

        sound = dsp.read('tests/sounds/guitar1s.wav')
        self.assertEqual(len(sound), 44100)
        self.assertTrue(sound.samplerate == 44100)

    def test_graph_soundfile(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        sound.graph('tests/renders/graph_soundbuffer.png', width=1280, height=800)

    def test_create_mono_buffer_from_soundfile(self):
        sound = SoundBuffer(filename='tests/sounds/linux.wav')
        self.assertTrue(sound.samplerate == 44100)
        self.assertTrue(sound.channels == 1)
        self.assertEqual(len(sound), 228554)

        sound = dsp.read('tests/sounds/linux.wav')
        self.assertTrue(sound.samplerate == 44100)
        self.assertTrue(sound.channels == 1)
        self.assertEqual(len(sound), 228554)

    def test_create_mono_buffer_from_wavetable(self):
        wt = dsp.wt('sine', wtsize=4096)
        self.assertTrue(len(wt) == 4096)

        snd = dsp.buffer(wt)
        self.assertTrue(len(snd) == 4096)
        self.assertTrue(snd[100][0] != 0)

        snd = SoundBuffer(wt)
        self.assertTrue(len(snd) == 4096)
        self.assertTrue(snd[100][0] != 0)

    def test_stack_soundbuffer(self):
        snd1 = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        snd2 = SoundBuffer(filename='tests/sounds/LittleTikes-A1.wav')
        channels = snd1.channels + snd2.channels
        length = max(len(snd1), len(snd2))
        out = dsp.stack([snd1, snd2])
        self.assertTrue(channels == out.channels)
        self.assertTrue(length == len(out))
        self.assertTrue(snd1.samplerate == out.samplerate)
        out.write('tests/renders/soundbuffer_stack.wav')

    def test_convolve_soundbuffer(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        impulse = SoundBuffer(filename='tests/sounds/LittleTikes-A1.wav')
        out = sound.convolve(impulse)
        out.write('tests/renders/soundbuffer_convolve_guitar_littletikes.wav')

        impulse = dsp.win('sinc')
        out = sound.convolve(impulse)
        out.write('tests/renders/soundbuffer_convolve_guitar_sinc.wav')

    def test_clip_soundbuffer(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        sound = sound.clip(-0.1, 0.1)

        self.assertEqual(len(sound), 44100)
        self.assertTrue(sound.samplerate == 44100)
        self.assertTrue(sound.max() <= 0.1)

    def test_save_buffer_to_soundfile(self):
        filename = path.join(self.soundfiles, 'test_save_buffer_to_soundfile.{}')
        sound = SoundBuffer(length=1)

        sound.write(filename.format('wav'))
        self.assertTrue(path.isfile(filename.format('wav')))

        sound.write(filename.format('flac'))
        self.assertTrue(path.isfile(filename.format('flac')))

        sound.write(filename.format('ogg'))
        self.assertTrue(path.isfile(filename.format('ogg')))

    def test_split_buffer(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        length = random.triangular(0.1, sound.dur) 
        framelength = int(length * sound.samplerate)
        durations = []
        for grain in sound.grains(length):
            durations += [ grain.dur ]

        # The final grain isn't padded with silence, 
        # so it should only be the grain length if 
        # it can be divided equally into the total 
        # length.
        for grain_length in durations[:-1]:
            self.assertEqual(int(grain_length * sound.samplerate), framelength)

        # Check that the remainder grain is the correct length
        remainderframes = int((sound.dur - sum(durations[:-1])) * sound.samplerate)
        self.assertEqual(int(durations[-1] * sound.samplerate), remainderframes)

        # Check that all the grains add up
        self.assertEqual(sum(durations), sound.dur)

    def test_random_split_buffer(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        durations = []
        for grain in sound.grains(0.001, sound.dur):
            durations += [ grain.dur ]

        # Check that the remainder grain is not 0
        self.assertNotEqual(durations[-1], 0)

        # Check that all the grains add up
        self.assertEqual(sum(durations), sound.dur)

    def test_window(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        for window_type in ('sine', 'saw', 'tri', 'hamm', 'hann', 'bart', 'kaiser', 'black'):
            sound = sound.env(window_type)
            self.assertEqual(sound[0], (0,0))

    def test_speed(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        speed = random.random()
        out = sound.speed(speed)
        out.write('tests/renders/soundbuffer_speed.wav')
        self.assertEqual(len(out), int(len(sound) * (1/speed)))

    def test_vpeed(self):
        sound = SoundBuffer(filename='tests/sounds/linux.wav')
        speed = dsp.win('hann', 0.5, 2)
        out = sound.vspeed(speed)
        out.write('tests/renders/soundbuffer_vspeed_0.5_2.wav')

        speed = dsp.win('hann', 0.15, 0.5)
        out = sound.vspeed(speed)
        out.write('tests/renders/soundbuffer_vspeed_0.15_0.5.wav')

        speed = dsp.win('hann', 5, 50)
        out = sound.vspeed(speed)
        out.write('tests/renders/soundbuffer_vspeed_5_50.wav')


    def test_transpose(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        speed = random.triangular(1, 10)
        out = sound.transpose(speed)
        self.assertEqual(len(out), len(sound))

        speed = random.triangular(0, 1)
        out = sound.transpose(speed)
        self.assertEqual(len(out), len(sound))

        speed = random.triangular(10, 100)
        out = sound.transpose(speed)
        self.assertEqual(len(out), len(sound))


    def test_pan(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        for pan_method in ('linear', 'constant', 'gogins'):
            # Hard pan smoke test
            pan_left = sound.pan(0, method=pan_method)
            self.assertEqual(pan_left[random.randint(0, len(pan_left))][0], 0)

            pan_right = sound.pan(1, method=pan_method)
            self.assertEqual(pan_right[random.randint(0, len(pan_right))][1], 0)

    def test_slice_frame(self):
        """ A SoundBuffer should return a single frame 
            when sliced into one-dimensionally like:

                frame = sound[frame_index]

            A frame is a tuple of floats, one value 
            for each channel of sound.
        """
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        indices = (0, -1, len(sound) // 2, -(len(sound) // 2))

        for frame_index in indices:
            frame = sound[frame_index]
            self.assertTrue(isinstance(frame, tuple))
            self.assertEqual(len(frame), sound.channels)
            self.assertTrue(isinstance(frame[0], float))

    def test_slice_sample(self):
        """ Slicing into the second dimension of a SoundBuffer
            will return a single sample at the given channel index.

                sample = sound[frame_index][channel_index]

            Note: A sample is a float, usually between -1.0 and 1.0 
            but pippi will only clip overflow when you ask it to, or 
            when writing a SoundBuffer back to a file. 
            So, numbers can exceed that range during processing and 
            be normalized or clipped as desired later on.
        """

        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        indices = (0, -1, len(sound) // 2, -(len(sound) // 2))

        for frame_index in indices:
            for channel_index in range(sound.channels):
                sample = sound[frame_index][channel_index]
                self.assertTrue(isinstance(sample, float))

    def test_pad_sound_with_silence(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')

        # Pad start
        original_length = len(sound)
        silence_length = random.triangular(0.001, 1)
        sound = sound.pad(silence_length)

        self.assertEqual(len(sound), int((sound.samplerate * silence_length) + original_length))
        self.assertEqual(sound[0], (0,0))

        # Pad end
        original_length = len(sound)
        silence_length = random.triangular(0.001, 1)
        sound = sound.pad(end=silence_length)

        self.assertEqual(len(sound), int((sound.samplerate * silence_length) + original_length))
        self.assertEqual(sound[-1], (0,0))

    def test_trim_silence(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav').env('hannout')
        firstval = abs(sum(sound[0]))
        lastval = abs(sum(sound[-1]))
        sound = sound.pad(start=1, end=1)

        self.assertEqual(sound.dur, 3)

        sound.write('tests/renders/trim_silence_before.wav')

        for threshold in (0, 0.01, 0.5):
            trimstart = sound.trim(start=True, end=False, threshold=threshold)
            trimstart.write('tests/renders/trim_silence_start%s.wav' % threshold)

            trimend = sound.trim(start=False, end=True, threshold=threshold)
            trimend.write('tests/renders/trim_silence_end%s.wav' % threshold)

    def test_taper(self):
        sound = SoundBuffer(filename='tests/sounds/guitar1s.wav')
        sound = sound.taper(0)
        sound = sound.taper(0.001)
        sound = sound.taper(0.01)
        sound = sound.taper(0.1)
        sound = sound.taper(1)
        sound = sound.taper(10)

        self.assertEqual(len(sound), 44100)
        self.assertTrue(sound.samplerate == 44100)

    def test_mul_soundbuffers(self):
        snd = dsp.buffer([1,2,3])
        self.assertEqual(len(snd), 3)
        self.assertEqual(snd * 2, dsp.buffer([2,4,6]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(snd * dsp.buffer([1,3,5]), dsp.buffer([1,6,15]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(dsp.buffer([1,3,5]) * snd, dsp.buffer([1,6,15]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        snd *= 2
        self.assertEqual(snd, dsp.buffer([2,4,6]))

        snd = dsp.buffer([1,2,3])
        mul = dsp.buffer([2,2,2])
        snd *= mul
        self.assertEqual(snd, dsp.buffer([2,4,6]))

    def test_add_soundbuffers(self):
        snd = dsp.buffer([1,2,3])
        self.assertEqual(len(snd), 3)
        self.assertEqual(snd + 2, dsp.buffer([3,4,5]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(snd + dsp.buffer([1,3,5]), dsp.buffer([1,2,3,1,3,5]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(dsp.buffer([1,3,5]) + snd, dsp.buffer([1,3,5,1,2,3]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        snd += 2
        self.assertEqual(snd, dsp.buffer([3,4,5]))

    def test_sub_soundbuffers(self):
        snd = dsp.buffer([1,2,3])
        self.assertEqual(len(snd), 3)

        self.assertEqual(snd - 1.5, dsp.buffer([-0.5, 0.5, 1.5]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(snd - 2, dsp.buffer([-1,0,1]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(snd - dsp.buffer([1,3,5]), dsp.buffer([0,-1,-2]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        self.assertEqual(dsp.buffer([1,3,5]) - snd, dsp.buffer([0,1,2]))
        self.assertEqual(snd, dsp.buffer([1,2,3]))

        snd -= 2
        self.assertEqual(snd, dsp.buffer([-1,0,1]))


