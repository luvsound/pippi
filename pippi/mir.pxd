#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport Wavetable
cimport numpy as np

cdef int DEFAULT_WINSIZE

cpdef np.ndarray flatten(SoundBuffer snd)

cdef np.ndarray _bandwidth(np.ndarray snd, int samplerate, int winsize)
cpdef Wavetable bandwidth(SoundBuffer snd, int winsize=*)

cdef np.ndarray _flatness(np.ndarray snd, int winsize)
cpdef Wavetable flatness(SoundBuffer snd, int winsize=*)

cdef np.ndarray _rolloff(np.ndarray snd, int samplerate, int winsize)
cpdef Wavetable rolloff(SoundBuffer snd, int winsize=*)

cdef np.ndarray _centroid(np.ndarray snd, int samplerate, int winsize)
cpdef Wavetable centroid(SoundBuffer snd, int winsize=*)

cdef np.ndarray _contrast(np.ndarray snd, int samplerate, int winsize)
cpdef Wavetable contrast(SoundBuffer snd, int winsize=*)

cpdef Wavetable pitch(SoundBuffer snd, double tolerance=*, str method=*, int winsize=*, bint backfill=*)

cpdef list onsets(SoundBuffer snd, str method=*, int winsize=*, bint seconds=*)
cpdef list segments(SoundBuffer snd, str method=*, int winsize=*)

