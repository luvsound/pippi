#include <signal.h>
#include <sys/syscall.h>

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_PULSEAUDIO
#define MA_NO_ALSA
#define MA_NO_ENCODING
#define MA_NO_DECODING
#include "miniaudio/miniaudio.h"
#include <hiredis/hiredis.h>

#include "astrid.h"


static volatile int astrid_is_running = 1;
int astrid_channels = 2;
lpscheduler_t * astrid_scheduler;

/* Callback for SIGINT */
void handle_shutdown(int sig __attribute__((unused))) {
    astrid_is_running = 0;
}

/* This callback fires when a buffer in the 
 * mixer has finished playback, and it originated 
 * from an instrument with loop enabled.
 **/
void retrigger_callback(void * arg) {
    lpeventctx_t * ctx;
    ctx = (lpeventctx_t *)arg;
    send_play_message(ctx);
}

void noop_callback(__attribute__((unused)) void * arg) {}

/* This callback runs in a thread started 
 * just before the audio callback is started.
 *
 * It waits on the buffer queue for new buffers, 
 * and then sends them to the scheduler.
 */
void * buffer_feed(__attribute__((unused)) void * arg) {
    redisContext * redis_ctx;
    redisReply * redis_reply;
    lpbuffer_t * buf;
    lpeventctx_t ctx = {0};
    struct timeval redis_timeout = {15, 0};
    size_t callback_delay = 0;

    syslog(LOG_INFO, "Buffer feed starting up...\n");
    redis_ctx = redisConnectWithTimeout("127.0.0.1", 6379, redis_timeout);
    if(redis_ctx == NULL) {
        syslog(LOG_CRIT, "Could not start connection to redis.\n");
        exit(1);
    }

    if(redis_ctx->err) {
        syslog(LOG_CRIT, "There was a problem while connecting to redis. %s\n", redis_ctx->errstr);
        exit(1);
    }

    /* Subscribe to the buffer queue. 
     * This is the only thread subscribed
     * to the buffer queue as a reader.
     */
    redis_reply = redisCommand(redis_ctx, "SUBSCRIBE astridbuffers");
    if(redis_reply->str != NULL) printf("subscribe result: %s\n", redis_reply->str); 
    freeReplyObject(redis_reply);

    /* Wait on buffers from the queue */
    syslog(LOG_INFO, "Waiting for buffers...\n");
    while(astrid_is_running && redisGetReply(redis_ctx, (void *)&redis_reply) == REDIS_OK) {
        if(redis_reply->type == REDIS_REPLY_ARRAY) {
            /*printf("Got message on redis buffer channel...\n");*/
            if(redis_reply->element[2]->str[0] == 's') {
                syslog(LOG_INFO, "Buffer feed got shutdown message\n");
                syslog(LOG_INFO, "    message: %s\n", redis_reply->element[2]->str);
                break;
            }
            buf = deserialize_buffer(redis_reply->element[2]->str, &ctx);
            if(buf->is_looping == 1) {
                syslog(LOG_DEBUG, "Scheduling buffer for retriggering at onset %d\n", (int)buf->onset);
                callback_delay = (size_t)(buf->length / 2);
                LPScheduler.schedule_event(astrid_scheduler, buf, buf->onset, retrigger_callback, &ctx, callback_delay);
            } else {
                syslog(LOG_DEBUG, "Scheduling buffer for single play at onset %d\n", (int)buf->onset);
                LPScheduler.schedule_event(astrid_scheduler, buf, buf->onset, noop_callback, NULL, callback_delay);
            }
        }
        freeReplyObject(redis_reply);
    }

    syslog(LOG_INFO, "Buffer feed shutting down...\n");

    if(redis_ctx != NULL) redisFree(redis_ctx); 
    return 0;
}

/* This callback runs in a thread managed by miniaudio.
 * It asks for samples from the mixer inside the scheduler 
 * and sends the mixed audio to the soundcard.
 */
void miniaudio_callback(
        ma_device * device, 
             void * pOut, 
    __attribute__((unused)) const void * pIn, 
          ma_uint32 count
) {
    ma_uint32 i;
    float * out;
    int c;
    lpdacctx_t * ctx;

    ctx = (lpdacctx_t *)device->pUserData;
    out = (float *)pOut;

    for(i=0; i < count; i++) {
        LPScheduler.tick(ctx->s);
        for(c=0; c < astrid_channels; c++) {
            *out++ = (float)ctx->s->current_frame[c];
        }
    }
}

int cleanup(ma_device * playback, lpdacctx_t * ctx, pthread_t buffer_feed_thread) {
    redisContext * redis_ctx;
    redisReply * redis_reply;
    struct timeval redis_timeout = {15, 0};

    redis_ctx = redisConnectWithTimeout("127.0.0.1", 6379, redis_timeout);
    if(redis_ctx == NULL) {
        syslog(LOG_ERR, "Could not start connection to redis.\n");
        exit(1);
    }

    if(redis_ctx->err) {
        syslog(LOG_ERR, "There was a problem while connecting to redis. %s\n", redis_ctx->errstr);
        exit(1);
    }

    syslog(LOG_INFO, "Sending shutdown to buffer thread...\n");
    astrid_is_running = 0;
    redis_reply = redisCommand(redis_ctx, "PUBLISH astridbuffers shutdown");
    if(redis_reply->str != NULL) syslog(LOG_INFO, "astridbuffers shutdown result: %s\n", redis_reply->str); 
    freeReplyObject(redis_reply);
    if(redis_ctx != NULL) redisFree(redis_ctx); 

    syslog(LOG_DEBUG, "Joining with buffer thread...\n");
    if(pthread_join(buffer_feed_thread, NULL) != 0) {
        syslog(LOG_ERR, "Error while attempting to join with buffer thread\n");
    }

    syslog(LOG_INFO, "Closing audio thread...\n");
    if(playback != NULL) ma_device_uninit(playback);

    syslog(LOG_INFO, "Cleaning up scheduler...\n");
    if(ctx != NULL) LPScheduler.destroy(ctx->s);

    syslog(LOG_INFO, "Freeing astrid context...\n");
    if(ctx != NULL) free(ctx);

    syslog(LOG_INFO, "Done with cleanup!\n");

    closelog();

    return 0;
}

int main() {
    char * _astrid_channels;
    struct sigaction shutdown_action;
    lpdacctx_t * ctx;
    pthread_t buffer_feed_thread;
    ma_device playback;

    ctx = NULL;
    openlog("astrid-dac", LOG_PID, LOG_USER);


    /* Set maximum output channels */
    /* FIXME get channels from available sound card ports */
    _astrid_channels = getenv("ASTRID_CHANNELS");
    if(_astrid_channels != NULL) {
        astrid_channels = atoi(_astrid_channels);
    }
    astrid_channels = ASTRID_CHANNELS;


    /* Set shutdown signal handlers */
    shutdown_action.sa_handler = handle_shutdown;
    sigemptyset(&shutdown_action.sa_mask);
    shutdown_action.sa_flags = 0;
    if(sigaction(SIGINT, &shutdown_action, NULL) == -1) {
        fprintf(stderr, "Could not init SIGINT signal handler.\n");
        exit(1);
    }

    if(sigaction(SIGTERM, &shutdown_action, NULL) == -1) {
        fprintf(stderr, "Could not init SIGTERM signal handler.\n");
        exit(1);
    }


    /* init scheduler and ctx 
     * 
     * The scheduler is shared between the miniaudio callback 
     * and astrid buffer feed threads. The buffer feed thread 
     * may schedule buffers by adding them to the internal linked 
     * list in the scheduler. The miniaudio callback may read from 
     * the linked list, increment counts in playing buffers and 
     * flag buffers as having playback completed. The main thread 
     * periodically triggers callbacks in the scheduler to be executed.
     *
     * The DAC context struct is a thin wrapper around the scheduler
     * given as a payload to the miniaudio callback and buffer feed.
     **/
    astrid_scheduler = LPScheduler.create(astrid_channels);
    ctx = (lpdacctx_t*)LPMemoryPool.alloc(1, sizeof(lpdacctx_t));
    ctx->s = astrid_scheduler;
    ctx->channels = ASTRID_CHANNELS;
    ctx->samplerate = ASTRID_SAMPLERATE;


    /* Setup and start buffer feed thread */
    if(pthread_create(&buffer_feed_thread, NULL, buffer_feed, ctx) != 0) {
        fprintf(stderr, "Could not initialize renderer thread\n");
        goto exit_with_error;
    }


    /* Setup and start miniaudio in playback mode */
    ma_device_config audioconfig = ma_device_config_init(ma_device_type_playback);
    audioconfig.playback.format = ma_format_f32;
    audioconfig.playback.channels = ASTRID_CHANNELS;
    audioconfig.sampleRate = ASTRID_SAMPLERATE;
    audioconfig.dataCallback = miniaudio_callback;
    audioconfig.pUserData = ctx;

    if(ma_device_init(NULL, &audioconfig, &playback) != MA_SUCCESS) {
        syslog(LOG_ERR, "Error while attempting to configure miniaudio for playback\n");
        goto exit_with_error;
    }

    syslog(LOG_INFO, "Miniaudio callback starting...\n");
    ma_device_start(&playback);

    syslog(LOG_INFO, "Astrid DAC is starting...\n");
    while(astrid_is_running) {
        /* Twiddle thumbs */
        usleep((useconds_t)1000);
        LPScheduler.handle_callbacks(ctx->s);
        /*LPScheduler.empty(ctx->s);*/
    }

    return cleanup(&playback, ctx, buffer_feed_thread);

exit_with_error:
    cleanup(&playback, ctx, buffer_feed_thread);
    syslog(LOG_ERR, "Exited with error\n");
    return 1;
}

