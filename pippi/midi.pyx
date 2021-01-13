#cython: language_level=3

import threading
import time

from libc cimport math
from pippi cimport dsp
from pippi import dsp
from pippi.events cimport Event

import mido

cpdef double mtof(double midi_note):
    return 2**((midi_note-69)/12.0) * 440

cpdef double ftom(double freq):
    return (math.log(freq / 440.0) / math.log(2)) * 12 + 69

cpdef int ftomi(double freq):
    return <int>(round(ftom(freq)))

def play(list events, int device_index=0):
    device = mido.open_output(mido.get_output_names()[device_index])

    midi_events = []
    for event in events:
        n = int(round(ftom(event.freq)))
        v = int(round(event.amp * 127))
        midi_events += [(event.onset, 'note_on', n, v)]
        midi_events += [(event.onset+event.length, 'note_off', n, 0)]

    midi_events = sorted(midi_events, key=lambda e: e[0])
    start_time = time.clock_gettime(time.CLOCK_MONOTONIC_RAW)
    queued = None

    while True:
        now = time.clock_gettime(time.CLOCK_MONOTONIC_RAW)
        elapsed = now - start_time
        if queued is None:
            try:
                event = midi_events.pop(0)
            except IndexError:
                break
        else:
            event = queued

        if elapsed >= event[0]:
            device.send(mido.Message(event[1], note=event[2], velocity=event[3]))
            queued = None
        else:
            queued = event

        time.sleep(0.0001)

def info():
    outputs = mido.get_output_names()
    inputs = mido.get_input_names()

    print('MIDI Devices')
    print('     OUTPUTS ->')
    for i, output in enumerate(outputs):
        print(f':::: {i} - {output}')

    print('     INPUTS ->')
    for i, input in enumerate(inputs):
        print(f':::: {i} - {input}')


