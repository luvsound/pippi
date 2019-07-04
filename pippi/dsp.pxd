#cython: language_level=3

from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport Wavetable

cdef double _mag(double[:,:] snd)
cpdef double mag(SoundBuffer snd)
cpdef list scale(list source, double fromlow=*, double fromhigh=*, double tolow=*, double tohigh=*, bint log=*)
cpdef list snap(list source, double mult=*, object pattern=*)
cpdef SoundBuffer mix(list sounds, align_end=*)
cpdef Wavetable randline(int numpoints, double lowvalue=*, double highvalue=*, int wtsize=*)
cpdef Wavetable wt(object values, object lowvalue=*, object highvalue=*, object wtsize=*)
cpdef Wavetable win(object values, object lowvalue=*, object highvalue=*, object wtsize=*)
cpdef SoundBuffer stack(list sounds)
cpdef SoundBuffer buffer(object frames=*, double length=*, int channels=*, int samplerate=*)
cpdef SoundBuffer read(object filename, double length=*, double start=*)
cpdef double rand(double low=*, double high=*)
cpdef int randint(int low=*, int high=*)
cpdef object choice(list choices)
cpdef void seed(object value=*)

