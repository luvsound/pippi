#include <unistd.h>
#include <signal.h>
#include <sys/time.h>

#define MINIAUDIO_IMPLEMENTATION
#define MA_ENABLE_ONLY_SPECIFIC_BACKENDS
#define MA_ENABLE_JACK
#define MA_NO_ENCODING
#define MA_NO_DECODING
#include "miniaudio/miniaudio.h"
#include <hiredis/hiredis.h>

#include "pippi.h"
#include "adc.h"

#define CHANNELS 2
#define SAMPLERATE 48000
#define ADC_LENGTH 1440000

static volatile int adc_is_capturing = 1;
lpadcctx_t * ctx;

void handle_shutdown(int) {
    adc_is_capturing = 0;
}

void lpadcctx_destroy(lpadcctx_t * ctx) {
    if(ctx->c != NULL) redisFree(ctx->c);
    if(ctx->r != NULL) freeReplyObject(ctx->r);
    LPBuffer.destroy(ctx->adc);
    free(ctx);
}

void miniaudio_callback(ma_device * device, void * pOut, const void * pIn, ma_uint32 count) {
    ma_uint32 i;
    float * in;
    int c;
    lpadcctx_t * ctx;

    ctx = (lpadcctx_t *)device->pUserData;
    in = (float *)pIn;

    ctx->r = redisCommand(ctx->c, "INCR blocksread");
    freeReplyObject(ctx->r);

    for(i=0; i < count; i++) {
        for(c=0; c < CHANNELS; c++) {
            ctx->adc->data[ctx->adc->pos * CHANNELS + c] = (lpfloat_t)*in++;
        }
        ctx->adc->pos += 1;
        ctx->adc->pos = ctx->adc->pos % ctx->adc->length;
    }
}

int main() {
    redisContext * status_redis;
    redisReply * status_reply;
    struct sigaction action;
    action.sa_handler = handle_shutdown;
    sigaction(SIGINT, &action, NULL);
    struct timeval redis_timeout = {15, 0};

    ctx = calloc(1, sizeof(lpadcctx_t));
    ctx->adc = LPBuffer.create(ADC_LENGTH, CHANNELS, SAMPLERATE);
    ctx->c = redisConnectWithTimeout("127.0.0.1", 6379, redis_timeout);
    status_redis = redisConnectWithTimeout("127.0.0.1", 6379, redis_timeout);
    
    if(ctx->c == NULL) {
        fprintf(stderr, "Could not start connection to redis.\n");
        goto exit_with_error;
    }

    if(ctx->c->err) {
        fprintf(stderr, "There was a problem while connecting to redis. %s\n", ctx->c->errstr);
        goto exit_with_error;
    }

    /* Configure miniaudio for playback mode */
    ma_device_config audioconfig = ma_device_config_init(ma_device_type_duplex);
    audioconfig.playback.format = ma_format_f32;
    audioconfig.playback.channels = CHANNELS;
    audioconfig.sampleRate = SAMPLERATE;
    audioconfig.dataCallback = miniaudio_callback;
    audioconfig.pUserData = ctx;

    /* init playback device */
    ma_device playback;
    if(ma_device_init(NULL, &audioconfig, &playback) != MA_SUCCESS) {
        fprintf(stderr, "Runtime Error while attempting to configure miniaudio for playback\n");
        goto exit_with_error;
    }

    /* start playback device */
    ma_device_start(&playback);

    while(adc_is_capturing) {
        usleep((useconds_t)10000);
        status_reply = redisCommand(status_redis, "GET blocksread");
        printf("blocksread %s\n", status_reply->str);
        freeReplyObject(status_reply);
    }

    redisFree(status_redis);
    ma_device_uninit(&playback);
    lpadcctx_destroy(ctx);
    return 0;

exit_with_error:
    if(status_redis != NULL) redisFree(status_redis);
    ma_device_uninit(&playback);
    lpadcctx_destroy(ctx);
    return 1;
}

