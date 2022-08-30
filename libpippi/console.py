import cmd
import threading
import subprocess

import mido
import redis

r = redis.StrictRedis(host='localhost', port=6379, db=0)
bus = r.pubsub()

PADMAP = {
    36: 'group1',
    37: 'group2',
    38: 'group3',
    39: 'group4',

    40: 'group5',
    41: 'group6',
    42: 'group7',
    43: 'group8',
}

def midi_relay(self, *args, **kwargs):
    with mido.open_input('LPD8:LPD8 MIDI 1 20:0') as lpd:
        for msg in lpd:
            if msg.type == 'note_on':
                #r.publish('astrid', 'play')
                r.publish(PADMAP[msg.note], 'play')
                print(PADMAP[msg.note], 'play')
            elif msg.type == 'note_off':
                #r.publish('astrid', 'stop')
                r.publish(PADMAP[msg.note], 'stop')
                print(PADMAP[msg.note], 'stop')
            elif msg.type == 'control_change':
                r.publish('astrid', 'setval:cc%s:float:%s' % (msg.control, msg.value/128.))

            print(msg)

class AstridConsole(cmd.Cmd):
    """ Astrid Console 
    """

    prompt = '^_- '
    intro = 'Astrid Console'
    instruments = {}

    def __init__(self, client=None):
        self.dac = subprocess.Popen('./build/dac')
        cmd.Cmd.__init__(self)

    def do_p(self, instrument):
        if instrument not in self.instruments:
            cmd = 'INSTRUMENT_PATH="orc/%s.py" INSTRUMENT_NAME="%s" ./build/renderer' % (instrument, instrument)
            self.instruments[instrument] = subprocess.Popen(cmd, shell=True)
        r.lpush('astrid-play-%s' % instrument, 'play')

    def do_r(self, cmd):
        r.publish('astrid', 'reload')

    def do_v(self, cmd):
        r.publish('astrid', 'setval:%s' % cmd)

    def do_i(self, cmd):
        #r.publish('astrid', 'status')
        print(self.instruments)

    def do_s(self, instrument):
        if instrument in self.instruments:
            r.lpush('astrid-play-%s' % instrument, 'stop')

    def do_k(self, instrument):
        if instrument in self.instruments:
            r.lpush('astrid-play-%s' % instrument, 'kill')
            self.instruments[instrument].terminate()

    def do_quit(self, cmd):
        for instrument in self.instruments:
            r.lpush('astrid-play-%s' % instrument, 'kill')
            self.instruments[instrument].terminate()

        self.dac.kill()
        self.quit()

    def do_EOF(self, line):
        return True

    def postloop(self):
        pass

    def start(self):
        self.cmdloop()

    def quit(self):
        print('Quitting')

if __name__ == '__main__':
    c = AstridConsole()
    #mr = threading.Thread(target=midi_relay, args=(None,))

    try:
        #mr.start()        
        c.start()
    except KeyboardInterrupt as e:
        c.quit()

    #mr.join()
