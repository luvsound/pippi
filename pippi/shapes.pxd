#cython: language_level=3

from pippi.wavetables cimport Wavetable
from pippi.soundbuffer cimport SoundBuffer

cpdef list onsets(double length, object density, object periodicity, object stability, double minfreq, double maxfreq)
cpdef SoundBuffer synth(object wt, double length=*, object density=*, object periodicity=*, object stability=*, double minfreq=*, double maxfreq=*, int samplerate=*, int channels=*)
cdef double[:] _table(double[:] out, unsigned int length, double[:] wt, double[:] density, double[:] periodicity, double[:] stability, double maxfreq, double minfreq, int samplerate)
cpdef Wavetable win(object waveform, double lowvalue=*, double highvalue=*, double length=*, object density=*, object periodicity=*, object stability=*, double minfreq=*, double maxfreq=*, int samplerate=*)
cpdef Wavetable wt(object waveform, double lowvalue=*, double highvalue=*, double length=*, object density=*, object periodicity=*, object stability=*, double minfreq=*, double maxfreq=*, int samplerate=*)

