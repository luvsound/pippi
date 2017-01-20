import mido
import multiprocessing as mp
from . import dsp
from . import tune

def list_output_devices():
    return mido.get_output_names()

def list_input_devices():
    return mido.get_input_names()

def list_devices():
    return {
        'input': list_input_devices(),
        'output': list_output_devices(),
    }

def validate_output_device_by_id(device_id, devices=None):
    device_id = int(device_id[1:])

    if devices is None:
        devices = list_devices()['output']

    try:
        return devices[device_id]
    except IndexError:
        return False


def validate_output_device(device):
    return device in list_output_devices()

def validate_input_device(device):
    return device in list_input_devices()

def print_devices():
    devices = list_devices()

    print 'Input devices:'
    for i, device in enumerate(devices['input']):
        print '  m%s %s' % (i, device)

    print
    print 'Output devices:'
    for i, device in enumerate(devices['output']):
        print '  m%s %s' % (i, device)

def input_log(ns, active=True):
    def log_listener():
        try:
            device_names = mido.get_input_names()
            devices = [ mido.open_input(device_name) for device_name in device_names ]
            devices = mido.ports.MultiPort(devices)
            for msg in devices:
                if hasattr(ns, 'midi_log_active'):
                    dsp.log(msg)
                else:
                    continue
        except IOError:
            dsp.log('Could not open MIDI devices for logging %s' % str(device_names))

    if active:
        if not hasattr(ns, 'midi_log_active'):
            listener = mp.Process(target=log_listener)
            listener.start()
            setattr(ns, 'midi_log_active', True)
    else:
        delattr(ns, 'midi_log_active')

def get_output_device(device):
    return mido.open_output(device)

def device_scribe(device_name, ns):
    try:
        with mido.open_input(device_name) as incoming:
            for msg in incoming:
                msg_id = None
                value = None
                if hasattr(msg, 'control'):
                    msg_id = msg.control
                    value = msg.value

                if hasattr(msg, 'note'):
                    msg_id = msg.note
                    value = msg.velocity
                    
                setattr(ns, '%s-%s-%s' % (device_name, msg.type, msg_id), value)

        delattr(ns, '%s-listener' % device_name)
    except IOError:
        dsp.log('Could not open MIDI device %s' % device_name)


def register_midi_listener(device_name, ns):
    # check to see if this device has a listener already
    # start one up if not
    if not hasattr(ns, '%s-listener' % device_name):
        try:
            listener = mp.Process(target=device_scribe, args=(device_name, ns))
            listener.start()
            setattr(ns, '%s-listener' % device_name, listener.pid)
        except IOError:
            dsp.log('Could not start listener for MIDI device: %s' % device_name)

def get_midi_readers(devices, mappings, ns):
    readers = {}
    for shortname, device_name in devices.iteritems():
        register_midi_listener(device_name, ns)
        readers[shortname] = MidiReader(device_name, ns, mappings=mappings)

    return readers

class MidiTrigger:
    def __init__(self, device_name, notes=None, cc=None):
        self.device_name = device_name
        self.notes = notes
        self.cc = cc

    def wait(self):
        try:
            with mido.open_input(self.device_name) as incoming:
                for msg in incoming:
                    if self.notes is not None:
                        if msg.type == 'note_on' and msg.note in self.notes:
                            return (msg.note, msg.velocity)

                    if self.cc is not None:
                        if msg.type == 'control_change' and msg.control in self.cc and msg.value > 0:
                            return (msg.control, msg.value)
        except IOError:
            dsp.log('Could not arm MIDI device %s' % self.device_name)

        return (None, None)

class MidiOutput:
    def __init__(self, device=None):
        self.playing = {}

        if device is None:
            self.config = config.init()
            device = self.config.get('device', None)

        self._out = mido.open_output(device)

    def noteon(self, freq, amp, channel=0):
        if channel not in self.playing:
            self.playing[channel] = []

        velocity = int(round(amp * 127.0))
        note = int(round(tune.ftom(freq)))
        self.playing[channel] += [ (note, velocity, channel) ]

        self._out.send(mido.Message('note_on', note=note, velocity=velocity, channel=channel))

    def stop(self, channel=None):
        if channel is None:
            voices = []
            for c, v in self.playing.iteritems():
                voices += v

            self.playing = {}

        else:
            try:
                voices = self.playing[channel]
                del self.playing[channel]
            except IndexError:
                voices = []

        for voice in voices:
            self._out.send(mido.Message('note_off', note=voice[0], velocity=voice[1], channel=voice[2]))



class MidiReader:
    def __init__(self, device_name, ns, offset=None, mappings=None):
        self.device_name = device_name
        self.ns = ns
        self.offset = offset
        self.mappings = mappings

    def setOffset(self, offset):
        self.offset = offset

    def geti(self, cc, default=None, low=0, high=1):
        return int(round(self.get(cc, default, low, high)))

    def getr(self, cc, default=None, low=0, high=1, mul=1):
        mul = 1 if mul > 1 else mul
        mul = dsp.rand(0, mul)

        value = self.get(cc, default, low, high)

        return value * mul

    def getri(self, cc, default=None, low=0, high=1, spread=1):
        return int(round(self.getr(cc, default, low, high, spread)))

    def get(self, cc, default=None, low=0, high=1):
        if self.mappings is not None and cc in self.mappings:
            cc = self.mappings[cc]

        if self.offset is not None:
            cc = cc + self.offset

        try:
            value = getattr(self.ns, '%s-control_change-%s' % (self.device_name, cc))
            return (value / 127.0) * (high - low) + low
        except Exception:
            if default is None:
                default = high 

            return default

    def note(self, midi_note, default=None, low=0, high=1):
        """ NOTE for note: this will just fetch note_on events 
            TODO: do we ever need to care about note_off here? 
        """

        try:
            velocity = getattr(self.ns, '%s-note_on-%s' % (self.device_name, midi_note))
            velocity = (velocity / 127.0) * (high - low) + low
        except Exception:
            if default is None:
                velocity = high
            else:
                velocity = default

        return velocity

class MidiClock:
    def __init__(self, device):
        self.out = mido.open_output(device)
        self.startmsg = mido.Message('start')
        self.stopmsg = mido.Message('stop')
        self.clockmsg = mido.Message('clock')

    def start(self):
        self.out.send(self.startmsg)

    def stop(self):
        self.out.send(self.stopmsg)

    def tick(self):
        self.out.send(self.clockmsg)

class MidiNote:
    def __init__(self, length=44100, note=60, freq=None, amp=None, velocity=127):
        self.length = length
        self.note = int(tune.ftom(freq)) if freq is not None else int(note)
        self.velocity = int(round(amp * 127.0)) if amp is not None else int(velocity)


