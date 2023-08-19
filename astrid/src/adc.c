#define MINIAUDIO_IMPLEMENTATION
#ifdef __linux__
#define MA_ENABLE_ONLY_SPECIFIC_BACKENDS
#define MA_ENABLE_JACK
#endif
#define MA_NO_ENCODING
#define MA_NO_DECODING
#include "miniaudio/miniaudio.h"

#include "astrid.h"


/* When false, the inner loop exits and begins cleanup */
static volatile int adc_is_running = 1;

/* When false, no frames are written into the shared buffer */
static volatile int adc_is_capturing = 1;

void handle_shutdown(int sig __attribute__((unused))) {
    adc_is_capturing = 0;
    adc_is_running = 0;
}

/* Audio callback: writes a block of frames into 
 * the shared circular buffer and increments the 
 * write position in the buffer. */
void miniaudio_callback(
    __attribute__((unused)) ma_device * device, 
    __attribute__((unused)) void * pOut, 
       const void * pIn, 
          ma_uint32 count
) {
    int adc_shmid;

    if(adc_is_capturing == 0) return;

    adc_shmid = *((int *)device->pUserData);

    if(lpadc_write_block(pIn, (size_t)(count * ASTRID_CHANNELS), adc_shmid) < 0) {
        syslog(LOG_ERR, "Could not write input block to ADC");
        return;
    }
}

int main() {
    int device_id, adc_shmid;
    ma_uint32 playback_device_count, capture_device_count;
    ma_device_info * playback_devices;
    ma_device_info * capture_devices;

    /* Open a handle to the system log */
    openlog("astrid-adc", LOG_PID, LOG_USER);

    /* setup signal handlers */
    struct sigaction shutdown_action;
    shutdown_action.sa_handler = handle_shutdown;
    sigemptyset(&shutdown_action.sa_mask);
    shutdown_action.sa_flags = SA_RESTART; /* Prevent open, read, write etc from EINTR */

    /* Keyboard interrupt triggers cleanup and shutdown */
    if(sigaction(SIGINT, &shutdown_action, NULL) == -1) {
        perror("Could not init SIGINT signal handler");
        exit(1);
    }

    /* Terminate signals also trigger cleanup and shutdown */
    if(sigaction(SIGTERM, &shutdown_action, NULL) == -1) {
        perror("Could not init SIGTERM signal handler");
        exit(1);
    }
    
    /* Create a shared memory region to be used as a circular 
     * buffer for renderer processes to read from */
    syslog(LOG_DEBUG, "Creating shared memory buffer for ADC\n");
    if((adc_shmid = lpadc_create()) < 0) {
        perror("Could not create adcbuf shared memory");
        return 1;
    }

    /* Set up the miniaudio device context */
    ma_context audio_device_context;
    if (ma_context_init(NULL, 0, NULL, &audio_device_context) != MA_SUCCESS) {
        syslog(LOG_ERR, "Error while attempting to initialize miniaudio device context\n");
        goto exit_with_error;
    }

    /* Populate it with some devices */
    if(ma_context_get_devices(&audio_device_context, &playback_devices, &playback_device_count, &capture_devices, &capture_device_count) != MA_SUCCESS) {
        syslog(LOG_ERR, "Error while attempting to get devices\n");
        goto exit_with_error;
    }

    /* Get the selected device ID */
    if((device_id = astrid_get_capture_device_id()) < 0) {
        syslog(LOG_CRIT, "Could not get capture device ID\n");
        goto exit_with_error;
    }

    /* Configure miniaudio for capture mode */
    ma_device_config audioconfig = ma_device_config_init(ma_device_type_capture);
    audioconfig.capture.format = ma_format_f32;
    audioconfig.capture.channels = ASTRID_CHANNELS;
    audioconfig.capture.pDeviceID = &capture_devices[device_id].id;
    audioconfig.sampleRate = ASTRID_SAMPLERATE;
    audioconfig.dataCallback = miniaudio_callback;
    audioconfig.pUserData = &adc_shmid;

    /* init miniaudio device */
    ma_device mad;
    syslog(LOG_INFO, "Opening device ID %d\n", device_id);
    if(ma_device_init(NULL, &audioconfig, &mad) != MA_SUCCESS) {
        syslog(LOG_ERR, "Error while attempting to configure device %d for capture\n", device_id);
        goto exit_with_error;
    }

    /* start miniaudio device */
    syslog(LOG_DEBUG, "Starting audio callback\n");
    ma_device_start(&mad);

    syslog(LOG_DEBUG, "ADC is now running!\n");
    while(adc_is_running) {
        usleep((useconds_t)1000);
    }

    syslog(LOG_DEBUG, "Exiting normally: shutting down audio\n");
    ma_device_uninit(&mad);

    syslog(LOG_DEBUG, "Exiting normally: cleaning up shared buffer\n");
    lpadc_destroy();
    return 0;

exit_with_error:
    syslog(LOG_DEBUG, "Attempting to clean up after exiting with error\n");
    ma_device_uninit(&mad);
    lpadc_destroy();
    return 1;
}

