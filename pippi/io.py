import dsp
import glob
import os
import sys
import time
import __main__
import multiprocessing as mp
import midi
from params import ParamManager
import config
import seq
import tune
import osc

try:
    import alsaaudio
    audio_engine = 'alsa'
except ImportError:
    try:
        import pyaudio
        audio_engine = 'portaudio'
        print 'Using experimental portaudio bindings. Please install alsaaudio if you have problems with sound playback.'
    except ImportError:
        print 'Playback disabled. Please install alsaaudio (ALSA) or pyaudio (PortAudio)'

class IOManager:
    def __init__(self):
        self.manager                = mp.Manager()
        self.ns                     = self.manager.Namespace()
        self.config                 = config.init()
        self.default_midi_device    = self.config.get('device', None)
        self.ns.device              = 'default'
        self.ns.grid                = False
        self.divcc                  = self.config.get('divcc', None)
        self.divs                   = [24, 12, 6, 8, 3] # Defines the order for MIDI control
        self.params                 = ParamManager(self.ns)

        self.ticks = {
            24: mp.Event(), # Quarter note
            12: mp.Event(), # Eighth note
            8: mp.Event(),  # Eighth note triplets
            6: mp.Event(),  # Sixteenth note
            3: mp.Event(),  # 32nd note
        }

        self.instruments            = self.findInstruments()
        self.playing                = self.manager.Namespace()
        self.playing.voices         = {}
        self.osc_servers            = {}

    def startOscServer(self, port=None):
        if port not in self.osc_servers:
            self.osc_servers[port] = osc.OscListener(port, self.ns)
            self.osc_servers[port].start()

    def findInstruments(self):
        instruments = []

        try:
            gens = glob.glob("*.py")
            for filename in gens:
                # Get base filename and strip .py extension
                filename = os.path.basename(filename)[:-3]
                instruments += [ filename ]

            if len(instruments) > 0:
                return instruments

            dsp.log('Discovered %s available instrument scripts' % len(instruments))

        except OSError:
            pass

        dsp.log('No instruments found')

        return instruments

    def validateInstrument(self, instrument_name):
        if instrument_name in self.instruments:
            return instrument_name
        return False

    def loadInstrument(self, instrument_name):
        sys.path.insert(0, os.getcwd())
        return __import__(instrument_name)

    def loadGridCtl(self):
        midi.register_midi_listener(self.default_midi_device, self.ns)
        return midi.MidiReader(self.default_midi_device, self.ns)

    def _stream(self, snd):
        try:
            os.nice(-2)
        except OSError:
            os.nice(0)

        out = self.openAudioDevice()
        out.write(snd)

    def register_voice_start(self, voice_id, instrument_name):
        voice_id = str(voice_id)
        if not hasattr(self.playing, voice_id):
            voices = self.playing.voices
            voices[voice_id] = instrument_name
            self.playing.voices = voices
            setattr(self.playing, voice_id, instrument_name)

    def register_voice_stop(self, voice_id):
        voice_id = str(voice_id)
        if hasattr(self.playing, voice_id):
            voices = self.playing.voices
            del voices[voice_id]
            self.playing.voices = voices
            delattr(self.playing, voice_id)

    def get_voice_info(self):
        return self.playing.voices

    def play(self, instrument_name, voice_id, loop=False):
        # register info / id for `i` cmd
        self.register_voice_start(voice_id, instrument_name)

        p = mp.Process(target=self._play, args=(instrument_name, voice_id, loop))
        p.start()

    def _play(self, instrument_name, voice_id, loop):
        # Load instrument module
        inst = self.loadInstrument(instrument_name)

        # Set up ctl data
        ctl = self.setupCtl(inst)
        grid_ctl = self.loadGridCtl()

        ctl['id'] = voice_id

        count = 0
        delay = None
        msg = None
        step = True
        once = True

        self.params.set('%s-loop' % voice_id, loop)

        if hasattr(inst, 'quantize'):
            self.params.set('%s-quantize' % voice_id, inst.quantize)

        if hasattr(inst, 'trigger') and inst.trigger:
            # TODO: add support for OSC triggers and maybe GPIO triggers? what else?
            trigger = midi.MidiTrigger(
                    inst.trigger.get('device'), 
                    inst.trigger.get('notes', None), 
                    inst.trigger.get('cc', None)
                )

        group = None
        if hasattr(inst, 'groups'):
            group = inst.groups[ voice_id % len(inst.groups) ]
        ctl['group'] = group

        if hasattr(inst, 'once'):
            ctl['once'] = inst.once(ctl)

        dsp.log('Playing voice %s' % voice_id)
        while self.params.get('%s-loop' % voice_id, True) or once:
            ctl['count'] = count

            if getattr(self.ns, 'reload', False) == True:
                reload(inst)
            
            ####################################
            # Wait for trigger if trigger is set
            ####################################
            triggered = False
            try:
                dsp.log('Voice %s waiting for trigger...' % voice_id)
                note_info = trigger.wait()
                ctl['note'] = note_info
                triggered = True

            except NameError:
                pass

            ##############################################
            # Wait for master clock tick if quantize is on
            ##############################################
            if hasattr(inst, 'QUANTIZE') and inst.QUANTIZE:
                if not self.ns.grid:
                    bpm = self.params.get('bpm', 120)
                    self.startGrid(bpm)

                div = grid_ctl.geti(self.divcc, low=0, high=4, default=0)
                div = self.divs[div]
                self.ticks[div].wait()

            #####################
            # sequence() playback
            #####################
            if hasattr(inst, 'sequence'):
                # Sequenced play
                step, delay, msg = inst.sequence(ctl)

                if step:
                    ctl['step'] = (step, delay, msg)

                    snd = inst.play(ctl)
                   
                    p = mp.Process(target=self._stream, args=(snd,))
                    p.start()

                if delay:
                    dsp.delay(delay)

            #####################
            # play() playback
            #####################
            elif hasattr(inst, 'play'):
                # spawn re-render
                def _render(inst, ctl, ns, voice_id):
                    snd = inst.play(ctl)
                    setattr(ns, '%s-buffer' % voice_id, snd)
                
                ########################
                # play() phrase playback
                ########################
                if hasattr(inst, 'phrase'):
                    phrase = inst.phrase(ctl)
                    ctl['phrase'] = phrase

                    for phrase_index, delay_length in enumerate(phrase.get('lengths', [0])):
                        ctl['phrase_index'] = phrase_index + 1

                        if not getattr(self.ns, '%s-mute' % voice_id, False):
                            if not hasattr(self.ns, '%s-buffer' % voice_id):
                                snd = inst.play(ctl)
                            else:
                                snd = getattr(self.ns, '%s-buffer' % voice_id)

                            p = mp.Process(target=_render, args=(inst, ctl, self.ns, voice_id))
                            p.start()

                            p = mp.Process(target=self._stream, args=(snd,))
                            p.start()

                        dsp.delay(delay_length)

                #########################
                # play() oneshot playback
                #########################
                else:
                    # End-to-end loop play
                    if not hasattr(self.ns, '%s-buffer' % voice_id):
                        snd = inst.play(ctl)
                    else:
                        snd = getattr(self.ns, '%s-buffer' % voice_id)

                    p = mp.Process(target=_render, args=(inst, ctl, self.ns, voice_id))
                    p.start()

                    if triggered:
                        dsp.log('Voice %s playback triggered' % voice_id)
                        # We don't want playback to block the main loop when triggering with MIDI/OSC
                        p = mp.Process(target=self._stream, args=(snd,))
                        p.start()
                    else:
                        # Blocking playback will restart the loop when playback is done
                        self._stream(snd)

            #####################
            # send() playback
            #####################
            elif hasattr(inst, 'send'):
                print 'playing'
                notes = inst.send(ctl)
                midi_out = midi.get_output_device(inst.midiout)
                print notes
                for note in notes:
                    print 'bout to play'
                    midi.play_note(midi_out, note.length, note.note, note.velocity)
                    print 'play note'

            count += 1
            once = False

        dsp.log('Stopping voice %s' % voice_id)
        self.register_voice_stop(voice_id)

    def setupCtl(self, inst, voice_index=0):
        param_manager = ParamManager(self.ns)
        osc_manager   = osc.OscManager(self.ns)

        midi_readers = None
        if hasattr(inst, 'midi'):
            mappings = None
            if hasattr(inst, 'mappings'):
                mappings = inst.mappings

            midi_readers = midi.get_midi_readers(inst.midi, mappings, self.ns)

        ctl = {
            'param': param_manager, # interface to session params set at the console
            'osc': osc_manager,     # osc i/o for param control
            'midi': midi_readers,   # midi i/o for param control
            'note': (None, None),   # for armed/triggered voices, this will be populated with note/velocity info
            'step': (None, None, None),
            'once': None,
            'count': 0,
        }

        return ctl

    def setReload(self, do_reload):
        setattr(self.ns, 'reload', do_reload)

    def openAudioDevice(self, device=None):
        if device is None:
            device = self.ns.device

        if audio_engine == 'alsa':
            out = self.open_alsa_pcm(device)
        elif audio_engine == 'portaudio':
            out = self.open_pyaudio_pcm(device)
        else:
            print 'Playback is disabled.'
            return False

        return out

    def stopAllInstruments(self, kill=False):
        for instrument_name in self.looping.keys():
            self.stopInstrument(instrument_name, kill)

    def stopInstrument(self, instrument_name, kill=False):
        if instrument_name in self.looping:
            for voice_id, process in self.looping[instrument_name].iteritems():
                setattr(self.ns, '%s-%s-loop' % (instrument_name, voice_id), False)

                if kill:
                    process.terminate()

            del self.looping[instrument_name]
            return True
        
        dsp.log('Could not stop %s instruments: none currently playing' % instrument_name)
        return False

    def stopGrid(self):
        self.ns.grid = False
        if self.grid and self.grid.is_alive():
            self.grid.terminate()

    def startGrid(self, bpm=120):
        ctl_device = self.default_midi_device
        midi.register_midi_listener(ctl_device, self.ns)
        ctl = midi.MidiReader(ctl_device, self.ns)

        self.grid = mp.Process(name='grid', target=self.gridHandler, args=(self.ticks, bpm, ctl))
        self.grid.start()
        self.ns.grid = True

    def gridHandler(self, divs, bpm, ctl=None):
        # TODO: send MIDI clock again, assign device via 
        # config file and/or console cmd. Also allow mapping 
        # MIDI control to grid tempo value without resetting
        os.nice(0)

        count = 0

        if self.params.get('clock', 'off') == 'on':
            clock = midi.MidiClock(self.default_midi_device)
            clock.start()

        while getattr(self.ns, 'grid', True):
            beat = dsp.bpm2frames(bpm) / 24

            if self.params.get('clock', 'off') == 'on':
                clock.tick()

            if count % 24 == 0:
                divs[24].set()
                divs[24].clear()

            if count % 12 == 0:
                divs[12].set()
                divs[12].clear()

            if count % 8 == 0:
                divs[8].set()
                divs[8].clear()

            if count % 6 == 0:
                divs[6].set()
                divs[6].clear()

            if count % 3 == 0:
                divs[3].set()
                divs[3].clear()

            dsp.delay(beat)
            count += 1

        if self.params.get('clock', 'off') == 'on':
            clock.stop()

    def set_bpm(self, bpm):
        if self.ns.grid:
            self.grid.terminate()

        self.startGrid(bpm)
 
    def open_alsa_pcm(self, device='default'):
        try:
            out = alsaaudio.PCM(alsaaudio.PCM_PLAYBACK, alsaaudio.PCM_NORMAL, device)
        except:
            print 'Could not open an ALSA connection.'
            return False

        out.setchannels(2)
        out.setrate(44100)
        out.setformat(alsaaudio.PCM_FORMAT_S16_LE)
        out.setperiodsize(10)

        return out

    def open_pyaudio_pcm(self, device='default'):
        self.p = pyaudio.PyAudio()

        out = self.p.open(
            format = self.p.get_format_from_width(2),
            channels = 2,
            rate = 44100,
            output = True
        )

        return out
