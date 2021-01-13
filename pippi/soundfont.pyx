#cython: language_level=3

import uuid

from libc.stdlib cimport malloc, free

import numpy as np
cimport numpy as np

from pippi.events cimport Event
from pippi.soundbuffer cimport SoundBuffer
from pippi.tune import ftom

np.import_array()

cdef int SAMPLERATE = 44100
cdef int CHANNELS = 2
cdef int BLOCKSIZE = 64
cdef int NOTE_ON = 0
cdef int NOTE_OFF = 1


cdef list parsemessages(list events, int samplerate):
    cdef list messages = []
    cdef dict m
    cdef Event e
    cdef str _id
    cdef int note
    cdef double fnote, frac
    cdef long start
    cdef long end
    
    for e in events:
        fnote = ftom(e.freq)
        note = <int>fnote
        frac = fnote - note
        start = <long>(e.onset * samplerate)
        end = <long>(e.length * samplerate) + start
        _id = str(uuid.uuid4())

        messages += [dict(id=_id, type=NOTE_ON, note=note, frac=frac, pos=start, amp=e.amp, instrument=e.voice)]
        messages += [dict(id=_id, type=NOTE_OFF, note=note, pos=end, instrument=e.voice)]

    return sorted(messages, key=lambda x: x['pos'])


cdef double[:,:] render(str font, list events, int voice, int channels, int samplerate):
    cdef tsf* TSF = tsf_load_filename(font.encode('UTF-8'))

    # Total length is last event onset time + length + 3 seconds of slop for the tail
    cdef long length = <long>(events[-1].onset + events[-1].length + 3) * samplerate

    # TSF only supports stereo or mono
    if channels == 1:
        tsf_set_output(TSF, TSF_MONO, samplerate, 0)
    else:
        channels = 2
        tsf_set_output(TSF, TSF_STEREO_UNWEAVED, samplerate, 0)

    cdef double[:,:] out = np.zeros((length, channels), dtype='d')
    cdef float* block = <float*>malloc(sizeof(float) * BLOCKSIZE * 2)

    cdef long elapsed = 0
    cdef long i = 0
    cdef int offset = 0
    cdef int c = 0
    cdef int channel = 0

    cdef list messages = parsemessages(events, samplerate)
    cdef dict channel_map = { c+1: [] for c in range(16) }
    cdef dict event_map = {} 

    while True:
        for msg in messages:
            if msg['pos'] > elapsed:
                break

            if msg['pos'] <= elapsed:
                tsf_channel_set_presetnumber(TSF, channel, msg['instrument'], False)

                if msg['type'] == NOTE_ON:
                    channel = -1

                    # look for a free channel not already playing this note
                    for c in channel_map.keys():
                        if msg['note'] not in channel_map[c]:
                            # Populate the maps for noteoff lookups
                            channel = c
                            channel_map[c] += [ msg['note'] ]
                            event_map[msg['id']] = channel
                            break

                    if channel < 0:
                        # All channels are in use, so ignore the note.
                        # Whaddya gonna do...?
                        continue

                    tsf_channel_mts_note_on(TSF, channel, <double>msg['note']+msg['frac'], msg['amp'])

                elif msg['type'] == NOTE_OFF:
                    if msg['id'] in event_map:
                        # If this event is playing, find the channel and cleanup
                        channel = event_map[msg['id']]
                        channel_map[channel].pop(channel_map[channel].index(msg['note']))
                        tsf_channel_note_off(TSF, channel, msg['note'])
                        del event_map[msg['id']]

                messages.pop(messages.index(msg))

        tsf_render_float(TSF, block, BLOCKSIZE, 0)

        for c in range(channels):
            offset = c * BLOCKSIZE
            for i in range(BLOCKSIZE):
                if i+elapsed < length:
                    out[i+elapsed,c] = block[i+offset]

        elapsed += BLOCKSIZE

        if elapsed > length:
            break

    free(block)
    tsf_close(TSF)

    return out

cpdef SoundBuffer play(str font, double length=1, double freq=440, double amp=1, int voice=1, int channels=CHANNELS, int samplerate=SAMPLERATE):
    cdef list events = [Event(onset=0, length=length, freq=freq, amp=amp, voice=voice)]
    return SoundBuffer(render(font, events, voice, channels, samplerate), channels=channels, samplerate=samplerate)

cpdef SoundBuffer playall(str font, object events, int voice=1, int channels=CHANNELS, int samplerate=SAMPLERATE):
    return SoundBuffer(render(font, events, voice, channels, samplerate), channels=channels, samplerate=samplerate)


