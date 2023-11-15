#ifndef LP_PULSAR_H
#define LP_PULSAR_H

#include "pippicore.h"

typedef struct lppulsarosc_t {
    lpfloat_t * wavetables;   /* Wavetable stack */
    int num_wavetables;
    size_t * wavetable_onsets;
    size_t * wavetable_lengths;
    lpfloat_t * wavetable_positions;
    lpfloat_t wavetable_phase;

    lpfloat_t * windows;  /* Window stack */
    int num_windows;
    size_t * window_onsets;
    size_t * window_lengths;
    lpfloat_t * window_positions;
    lpfloat_t window_phase;

    void * burst;         /* Burst table - null table == pulses always on */
    size_t burst_size;
    lpfloat_t burst_pos;

    lpfloat_t saturation; /* Probability of all pulses to no pulses */
    lpfloat_t pulsewidth;
    lpfloat_t samplerate;
    lpfloat_t freq;
} lppulsarosc_t;

typedef struct lppulsarosc_factory_t {
    lppulsarosc_t * (*create)(int num_wavetables, 
        lpfloat_t * wavetables, 
        size_t * wavetable_onsets,
        size_t * wavetable_lengths,

        int num_windows, 
        lpfloat_t * windows, 
        size_t * window_onsets,
        size_t * window_lengths
    );
    lpfloat_t (*process)(lppulsarosc_t *);
    void (*destroy)(lppulsarosc_t*);
} lppulsarosc_factory_t;

extern const lppulsarosc_factory_t LPPulsarOsc;

#endif
