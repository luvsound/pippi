# Pippi: Computer music with python

This is pre-release software. I am working toward a stable 1.0 and would very much appreciate bug reports, feedback and pull requests!

## Installation

> Note: pippi is currently only compatible with Python 2.x

Pippi was built to run on Linux, OSX and Windows. Linux is fully supported. OSX support is pretty good 
and getting better. Windows is almost completely untested -- seeking beta testers!

### MIDI Support

To enable MIDI support, install the `portmidi` package on your system. (Available via homebrew on OSX)

### C extension support

In order to build the C extensions that pippi uses for most DSP, you will need to install the Python 
development headers. On some systems (like arch linux) this will already be installed.

On debian (including ubuntu & raspbian) systems:

    apt-get install python-dev

On OSX you may need to install xcode to build the C extensions: http://docs.python-guide.org/en/latest/starting/install/osx/

### To install latest version from source:

Make sure you have `pip` installed on your system, since pippi uses the version of `setuptools` distributed with pip for installation.

To use the interactive features you will need to install `pyalsaaudio` (for ALSA support on linux) or `pyaudio` for experimental cross-platform audio support on OSX and Windows.

You may need to install the `libasound2-dev` package on debian systems with `apt-get` before you will be able to install `pyalsaaudio`.

If you're trying the experimental `pyaudio` support, you may need to install `portaudio` on your system first.

When you have the dependencies you selected installed, from the root of the pippi repository run:
    
    python setup.py install

## Linux Installation

## Debian / Ubuntu Installation

## Raspian Installation

## Arch Linux Installation

## Windows Installation

- Install git
- Install python 2.7
- install cgywin and these packages:
    - autoconf
    - make
    - libtool
    - libportmidi-devel
    - python-pyportmidi
    - libportaudio-devel
    - gcc-g++
- run `python -m ensurepip` to install pip and setuptools
- clone pippi & checkout master branch
- From pippi directory run `python setup.py install`

## Now What?

Here's a simple 'Hello World!' style example you can try at the python console:

    >>> from pippi import dsp
    >>> out = dsp.tone(dsp.stf(5), freq=220, amp=0.2)
    >>> out = dsp.env(out, 'hann')
    >>> dsp.write(out, 'hello')
    'hello.wav'

Here's a slightly more interesting example:

    >>> from pippi import dsp
    >>> out = [ dsp.tone(dsp.stf(5), 55 * i, 'sine2pi', 0.2) for i in range(1, 5) ]
    >>> out = [ dsp.env(o, dsp.randchoose(['hann', 'tri', 'sine'])) for o in out ]
    >>> out = dsp.mix(out)
    >>> dsp.write(out, 'helloagain')
    'helloagain.wav'

### Interactive example

Pippi can use scripts as "generators" for interactive playback and performance.

Here's a simple example generator based on the previous example:

    from pippi import dsp, tune

    def play(ctl):
        key = ctl.get('param').get('key', 'c')
        freqs = tune.fromdegrees([1,3,5,8], octave=3, root=key)
        freq = dsp.randchoose(freqs)
        length = dsp.stf(2, 5) # between 2 & 5 seconds
        waveshape = dsp.randchoose(['sine', 'tri', 'square'])
        amp = dsp.rand(0.1, 0.2)

        out = dsp.tone(length, freq, waveshape, amp)
        out = dsp.env(out, 'phasor')
        out = dsp.taper(out, 20)

        return out


Save it as example.py and from the same directory type `pippi` to enter the interactive console.

To play the example.py generator type:

    ^_- p example

To find the playing voice ID:

    ^_- i

    1 example

To stop voice ID 1:

    ^_- s 1

To have pippi reload the script to allow you to alter the code and hear the changes as it plays, type:

    ^_- reload on

To change the current key (which is just an arbitrary parameter set in the pippi console session) from C major to Eb major:

    ^_- key eb

The above example instrument script uses looping playback, which will rerender and play the output of `play()` until stopped.

To sequence a polyphonic phrase within the instrument script, add a `sequence()` function:

    from pippi import dsp, tune

    def sequence(ctl):
        # on every step, generate a random step length
        # The first item in the tuple will mute the voice 
        # (play a rest) if False, and play a note if True.
        # The last item in the tuple is an optional message
        # that will be passed to the play() function
        return (True, dsp.mstf(100, 500), None)

    def play(ctl):
        key = ctl.get('param').get('key', 'c')
        freqs = tune.fromdegrees([1,3,5,8], octave=3, root=key)
        freq = dsp.randchoose(freqs)
        length = dsp.stf(2, 5) # between 2 & 5 seconds
        waveshape = dsp.randchoose(['sine', 'tri', 'square'])
        amp = dsp.rand(0.1, 0.2)

        out = dsp.tone(length, freq, waveshape, amp)
        out = dsp.env(out, 'phasor')
        out = dsp.taper(out, 20)

        return out

And start playback in the same way:

    ^_- p example

The `sequence()` function is called every time a note is played, 
so you may want to generate random sequences once when the voice begins
to play by adding a `once()` function:

    from pippi import dsp, tune

    def once(ctl):
        numsteps = 12
        steps = []

        lengths = [
            dsp.mstf(100), 
            dsp.mstf(300), 
            dsp.mstf(150), 
        ]

        for _ in range(numsteps):
            steps += [ (True, dsp.randchoose(lengths), None) ]

        return steps

    def sequence(ctl):
        # count increments as each note plays
        count = ctl.get('count', 0)

        # get our fixed sequence from once
        steps = ctl.get('once', [])

        # loop over the steps with the play count
        return steps[ count % len(steps) ]

    def play(ctl):
        key = ctl.get('param').get('key', 'c')
        freqs = tune.fromdegrees([1,3,5,8], octave=3, root=key)
        freq = dsp.randchoose(freqs)
        length = dsp.stf(2, 5) # between 2 & 5 seconds
        waveshape = dsp.randchoose(['sine', 'tri', 'square'])
        amp = dsp.rand(0.1, 0.2)

        out = dsp.tone(length, freq, waveshape, amp)
        out = dsp.env(out, 'phasor')
        out = dsp.taper(out, 20)

        return out


More commands and help available by typing `help` at the console

[More documentation at Read The Docs.](http://pippi.readthedocs.org)

