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
    void tsf_render_float(tsf* f, float* buffer, int samples, int flag_mixing)
    void tsf_reset(tsf* f)
    
cdef double[:,:] render(str font, object events, int voice, int channels, int samplerate)
cpdef SoundBuffer play(str font, double length=*, double freq=*, double amp=*, int voice=*, int channels=*, int samplerate=*)
cpdef SoundBuffer playall(str font, object events, int voice=*, int channels=*, int samplerate=*)
