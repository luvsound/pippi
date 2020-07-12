
from pippi import dsp

guitar = dsp.read('tests/sounds/guitar10s.wav')

print('%s: %s frames / %.2f seconds' % (type(guitar), len(guitar), guitar.dur))

guitar.write('docs/tutorials/renders/001-guitar-unaltered.flac')

slow_guitar = guitar.speed(0.5)

print(slow_guitar)

slow_guitar.write('docs/tutorials/renders/001-guitar-slow.wav')

mixed_guitars = slow_guitar & guitar
mixed_guitars.write('docs/tutorials/renders/001-guitar-mixed.wav')
print(mixed_guitars)

out = dsp.buffer()

from pippi import tune

freqs = tune.chord('I', key='C', octave=3, ratios=tune.JUST)

print('Cmaj: %s' % freqs)

original_freq = tune.ntf('A2')

speeds = [ new_freq / original_freq for new_freq in freqs ]

pos = 0  
beat = 1.5
out = dsp.buffer()
for speed in speeds:
    # Create a pitch-shifted copy of the original guitar
    note = guitar.speed(speed)

    # Dub it into the output buffer at the current position in seconds
    out.dub(note, pos)

    # Just for fun, lets also dub another copy 400 milliseconds (0.4 seconds) later that's an octave higher
    note = guitar.speed(speed * 2)
    out.dub(note, pos + 0.4) 

    # Now move the write position forward 1.5 seconds
    pos += beat

# Save this output buffer
out.write('docs/tutorials/renders/001-guitar-chord.wav')

pos = 0  
beat = 1.5
out = dsp.buffer()

# Get the frequencies of an F minor 11th chord tuned to a 
# set of ratios devised by Terry Riley starting on F2
freqs = tune.chord('ii11', key='e', octave=2, ratios=tune.TERRY)

# Convert the frequencies to speeds
speeds = [ freq / original_freq for freq in freqs ]

# Loop 4x through the speeds
for speed in speeds * 4:
    # First lets cut the length of this note shorter to make 
    # it easier to hear how the envelope sounds.
    #
    # `cut(0...` will cut a section from the beginning of the 
    # sound until somewhere between 0.1 and 3 seconds later.
    note = guitar.speed(speed).cut(0, dsp.rand(0.1,3))

    # Apply an ADSR envelope to the note
    note = note.adsr(
        a=dsp.rand(0.05, 0.2), # Attack between 50ms and 200ms
        d=dsp.rand(0.1, 0.3),  # Decay between 100ms and 300ms
        s=dsp.rand(0.1, 0.5),  # Sustain between 10% and 50%
        r=dsp.rand(1, 2)       # Release between 1 and 2 seconds*
    )

    # * If the note is shorter than the sum of the ASDR lengths, 
    #   the release period is adjusted to whatever is left over.

    # This time, lets use the `&` operator to mix each speed, 
    # and pad the beginning of the higher sound with (less) silence 
    # instead of adding an offset to the position when we dub it.
    note = note & note.speed(2).pad(dsp.rand(0, 0.05))

    # Calculate the number of tremelos we want per note based 
    # on the desired tremelo length
    tremelo_length = dsp.rand(0.05, 0.1) # between 50 and 100 milliseconds
    num_tremelos = note.dur // tremelo_length

    # Create a new `Wavetable` with a sinewave repeated `num_tremelos` times.
    # We're creating a window here, which means by default the wavetable will 
    # always go from 0 to 1, and the built-in shapes are period-adjusted so you 
    # just get a single sine hump for example, not both sides of a full sinewave 
    # from -1 to 1 that you'd get using `dsp.wt('sine')` instead.
    tremelo = dsp.win('sine').repeated(num_tremelos) 

    # Multiply the note by the tremelo. This will have the effect of doing an 
    # amplitude modulation on the sound. The object on the right side of the 
    # statement will be resized and interpolated to match the size of the object 
    # on the left side of the statement. 
    # `sound.env('sine')` is the same as `sound * dsp.win('sine')`
    note = note * tremelo

    out.dub(note, pos)
    pos += beat

# Introducing... the `fx` module! 
from pippi import fx

# Lets also normalize the final result to 0db (or a magnitude of 1)
out = fx.norm(out, 1)

# Save this output buffer
out.write('docs/tutorials/renders/001-guitar-chord-enveloped.wav')
