#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer

cdef extern from "tsf.h":
    struct tsf:
        pass

    enum TSFOutputMode:
        TSF_STEREO_INTERLEAVED
        TSF_STEREO_UNWEAVED
        TSF_MONO

    tsf* tsf_load_filename(const char* filename)
    void tsf_set_output(tsf* f, TSFOutputMode outputmode, int samplerate, float global_gain_db)
    void tsf_note_on(tsf* f, int preset_index, int key, float vel)
    void tsf_note_off(tsf* f, int preset_index, int key)
    void tsf_render_float(tsf* f, float* buffer, int samples, int flag_mixing)
    void tsf_reset(tsf* f)
    void tsf_channel_mts_note_on(tsf* f, int channel, double key, float vel)
    void tsf_channel_note_on(tsf* f, int channel, int key, float vel)
    void tsf_channel_note_off(tsf* f, int channel, int key)
    void tsf_channel_note_off_all(tsf* f, int channel)
    void tsf_channel_set_pitchwheel(tsf* f, int channel, int pitch_wheel)
    void tsf_channel_midi_control(tsf* f, int channel, int controller, int control_value)
    int tsf_channel_set_presetnumber(tsf* f, int channel, int preset_number, int flag_mididrums)
    int tsf_active_voice_count(tsf* f)
   
cdef double[:,:] render(str font, list events, int voice, int channels, int samplerate)
cpdef SoundBuffer play(str font, double length=*, double freq=*, double amp=*, int voice=*, int channels=*, int samplerate=*)
cpdef SoundBuffer playall(str font, object events, int voice=*, int channels=*, int samplerate=*)
