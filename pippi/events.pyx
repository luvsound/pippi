#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

cdef tuple reserved = ('onset', 'length', 'freq', 'amp', 'pos', 'count')

cpdef object rebuild_event(double onset, double length, double freq, double amp, double pos, int count, object before, dict params):
    return Event(onset, length, freq, amp, pos, count, before, params)

cdef class Event:
    def __cinit__(self, 
            double onset=0,
            double length=1,
            double freq=220.0,
            double amp=1,
            double pos=0, 
            int count=0,
            object before=None,
            dict params=None,
            **kwargs,
        ):
        self.onset = onset
        self.length = length
        self.freq = freq
        self.amp = amp
        self.pos = pos
        self.count = count
        self._before = before

        if params is None:
            params = {}

        params.update(kwargs)

        self._params = params

    def __reduce__(self):
        return (rebuild_event, (self.onset, self.length, self.freq, self.amp, self.pos, self.count, self._before, self._params))

    def __getattr__(self, key):
        return self.get(key)

    def __setattr__(self, key, value):
        if key not in reserved:
            self._params[key] = value
        else:
            super(self).__setattr__(key, value)

    def get(self, key, default=None):
        if key in self._params:
            return self._params.get(key, default)
        else:
            self._params[key] = default

cdef SoundBuffer render(list events, object callback, int channels, int samplerate):
    cdef double end = events[-1].onset + events[-1].length
    cdef SoundBuffer out = SoundBuffer(length=end, channels=channels, samplerate=samplerate)

    cdef int count = 0
    cdef double pos = 0
    cdef Event event
    cdef SoundBuffer segment

    for event in events:
        event.count = count
        event.pos = (event.onset or 0) / end
        event._params['channels'] = channels
        event._params['samplerate'] = samplerate

        if event._before is not None:
            event.before = event._before(event)

        segment = callback(event)

        out.dub(segment, event.onset or 0)
        count += 1

    return out
