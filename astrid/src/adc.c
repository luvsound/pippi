#include <signal.h>
#include <string.h>

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_PULSEAUDIO
#define MA_NO_ALSA
#define MA_NO_ENCODING
#define MA_NO_DECODING
#include "miniaudio/miniaudio.h"

#include "astrid.h"


static volatile int adc_is_running = 1;
static volatile int adc_is_capturing = 1;

void handle_shutdown(int sig __attribute__((unused))) {
    adc_is_capturing = 0;
    adc_is_running = 0;
}

void miniaudio_callback(
        ma_device * device, 
    __attribute__((unused)) void * pOut, 
       const void * pIn, 
          ma_uint32 count
) {
    ma_uint32 i;
    float * in;
    int c;
    lpadcbuf_t * adcbuf;
    lpfloat_t sample;
    size_t frame = 0;

    adcbuf = (lpadcbuf_t *)device->pUserData;
    in = (float *)pIn;

    if(adc_is_capturing == 0) return;

    if (lpadc_get_pos(adcbuf, &frame) < 0) goto exit_callback_with_error;
    for(i=0; i < count; i++) {
        for(c=0; c < ASTRID_CHANNELS; c++) {
            sample = (lpfloat_t)*in++;
            if (lpadc_write_sample(adcbuf, sample, frame, c, i) < 0) goto exit_callback_with_error;
        }

    }
    if (lpadc_increment_pos(adcbuf, count) < 0) goto exit_callback_with_error;
    return;

exit_callback_with_error:
    adc_is_running = 0;
}

int main() {
    lpadcbuf_t * adcbuf;

    /* setup SIGNINT handler for shutdown */
    struct sigaction action;
    action.sa_handler = handle_shutdown;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;
    if(sigaction(SIGINT, &action, NULL) == -1) {
        fprintf(stderr, "Could not init SIGINT signal handler.\n");
        exit(1);
    }

    if(sigaction(SIGTERM, &action, NULL) == -1) {
        fprintf(stderr, "Could not init SIGTERM signal handler.\n");
        exit(1);
    }
    
    /* Create shared memory buffer */
    adcbuf = lpadc_create();
    if(adcbuf == NULL) {
        fprintf(stderr, "Runtime Error while attempting to create shared memory buffer\n");
        lpadc_destroy(adcbuf);
        return 1;
    }

    /* Configure miniaudio for capture mode */
    ma_device_config audioconfig = ma_device_config_init(ma_device_type_capture);
    audioconfig.capture.format = ma_format_f32;
    audioconfig.capture.channels = ASTRID_CHANNELS;
    audioconfig.sampleRate = ASTRID_SAMPLERATE;
    audioconfig.dataCallback = miniaudio_callback;
    audioconfig.pUserData = adcbuf;

    /* init miniaudio device */
    ma_device mad;
    if(ma_device_init(NULL, &audioconfig, &mad) != MA_SUCCESS) {
        fprintf(stderr, "Runtime Error while attempting to configure miniaudio\n");
        goto exit_with_error;
    }

    /* start miniaudio device */
    ma_device_start(&mad);

    while(adc_is_running) {
        usleep((useconds_t)1000);
    }

    ma_device_uninit(&mad);
    lpadc_close(adcbuf);
    lpadc_destroy(adcbuf);
    return 0;

exit_with_error:
    ma_device_uninit(&mad);
    lpadc_close(adcbuf);
    lpadc_destroy(adcbuf);
    return 1;
}

