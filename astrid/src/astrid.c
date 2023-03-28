#include "astrid.h"


int lpsampler_get_length(lpsampler_t * sampler, size_t * length) {
    struct flock fl;
    fl.l_type = F_RDLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = sampler->length_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(sampler->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a read lock on sampler length.\n");
        return -1;
    } else {
        memcpy(length, sampler->buf+sampler->length_offset, sizeof(size_t));

        fl.l_type = F_UNLCK;
        if(fcntl(sampler->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock sampler length read lock.\n");
            return -1;
        }
    }

    return 0;
}

int lpsampler_get_samplerate(lpsampler_t * sampler, int * samplerate) {
    struct flock fl;
    fl.l_type = F_RDLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = sampler->samplerate_offset;
    fl.l_len = sizeof(int);

    if(fcntl(sampler->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a read lock on sampler samplerate.\n");
        return -1;
    } else {
        memcpy(samplerate, sampler->buf+sampler->samplerate_offset, sizeof(int));

        fl.l_type = F_UNLCK;
        if(fcntl(sampler->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock sampler samplerate read lock.\n");
            return -1;
        }
    }

    return 0;
}

int lpsampler_get_channels(lpsampler_t * sampler, int * channels) {
    struct flock fl;
    fl.l_type = F_RDLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = sampler->channels_offset;
    fl.l_len = sizeof(int);

    if(fcntl(sampler->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a read lock on sampler channels.\n");
        return -1;
    } else {
        memcpy(channels, sampler->buf+sampler->channels_offset, sizeof(int));

        fl.l_type = F_UNLCK;
        if(fcntl(sampler->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock sampler channels read lock.\n");
            return -1;
        }
    }

    return 0;
}

lpsampler_t * lpsampler_create_from(int bankid, lpbuffer_t * buf) {
    lpsampler_t * sampler;

    sampler = (lpsampler_t *)calloc(sizeof(lpsampler_t), 1);
    sampler->name = calloc(SAMPLER_NAME_SIZE, sizeof(char));
    snprintf(sampler->name, SAMPLER_NAME_SIZE, SAMPLER_NAME_TEMPLATE, bankid);
    sampler->fd = shm_open(sampler->name, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR);
    if(sampler->fd == -1) {
        perror("Could not get a handle to sampler shared memory.\n");
        return NULL;
    }

    /* FIXME get samplerate & channels from context */
    sampler->length = buf->length;
    sampler->samplerate = buf->samplerate;
    sampler->channels = buf->channels;

    sampler->length_offset = 0;
    sampler->samplerate_offset = sampler->length_offset + sizeof(size_t);
    sampler->channels_offset = sampler->samplerate_offset + sizeof(int);
    sampler->buffer_offset = sampler->channels_offset + sizeof(int);
    sampler->total_bytes = sampler->buffer_offset + (sizeof(lpfloat_t) * sampler->length * sampler->channels);

    if(ftruncate(sampler->fd, sampler->total_bytes) == -1) {
        perror("Could not resize sampler.\n");
        return NULL;
    }

    sampler->buf = mmap(NULL, sampler->total_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, sampler->fd, 0);
    if(sampler->buf == MAP_FAILED) {
        perror("Could not mmap sampler.\n");
        return NULL;
    }

    memcpy(sampler->buf+sampler->length_offset, &sampler->length, sizeof(size_t));
    memcpy(sampler->buf+sampler->samplerate_offset, &sampler->samplerate, sizeof(int));
    memcpy(sampler->buf+sampler->channels_offset, &sampler->channels, sizeof(int));
    memcpy(sampler->buf+sampler->buffer_offset, &buf->data, sizeof(lpfloat_t) * sampler->length);

    return sampler;
}

lpsampler_t * lpsampler_open(int bankid) {
    lpsampler_t * sampler;
    struct stat buffdstat;

    sampler = (lpsampler_t *)calloc(sizeof(lpsampler_t), 1);
    sampler->name = calloc(SAMPLER_NAME_SIZE, sizeof(char));
    snprintf(sampler->name, SAMPLER_NAME_SIZE, SAMPLER_NAME_TEMPLATE, bankid);
    sampler->fd = shm_open(sampler->name, O_RDONLY, 0);
    if(sampler->fd == -1) {
        perror("lpadc_open: Could not open a handle to sampler shared memory.\n");
        return NULL;
    }

    /* fstat check size */
    if(fstat(sampler->fd, &buffdstat) == -1) {
        perror("lpadc_open: Could not fstat sampler shared memory.\n");
        return NULL;
    }

    sampler->total_bytes = buffdstat.st_size;

    sampler->length_offset = 0;
    sampler->samplerate_offset = sampler->length_offset + sizeof(size_t);
    sampler->channels_offset = sampler->samplerate_offset + sizeof(int);
    sampler->buffer_offset = sampler->channels_offset + sizeof(int);

    sampler->buf = mmap(NULL, sampler->total_bytes, PROT_READ, MAP_SHARED, sampler->fd, 0);
    if(sampler->buf == MAP_FAILED) {
        perror("lpadc_open: Could not mmap sampler.\n");
        return NULL;
    }

    if(lpsampler_get_length(sampler, &sampler->length) == -1) {
        perror("Could not read sampler length from shm\n");
        return NULL;
    }

    if(lpsampler_get_samplerate(sampler, &sampler->samplerate) == -1) {
        perror("Could not read sampler samplerate from shm\n");
        return NULL;
    }

    if(lpsampler_get_channels(sampler, &sampler->channels) == -1) {
        perror("Could not read sampler channels from shm\n");
        return NULL;
    }

    return sampler;
}

lpsampler_t * lpsampler_dub(int bankid, lpbuffer_t * buf) {
    lpsampler_t * sampler;
    lpbuffer_t * tmpbuf;
    struct stat buffdstat;

    sampler = (lpsampler_t *)calloc(sizeof(lpsampler_t), 1);
    sampler->name = calloc(SAMPLER_NAME_SIZE, sizeof(char));
    snprintf(sampler->name, SAMPLER_NAME_SIZE, SAMPLER_NAME_TEMPLATE, bankid);
    sampler->fd = shm_open(sampler->name, O_RDWR, 0);
    if(sampler->fd == -1) {
        perror("lpadc_open: Could not open a handle to sampler shared memory.\n");
        return NULL;
    }

    /* fstat check size */
    if(fstat(sampler->fd, &buffdstat) == -1) {
        perror("lpadc_open: Could not fstat sampler shared memory.\n");
        return NULL;
    }

    sampler->total_bytes = buffdstat.st_size;

    sampler->length_offset = 0;
    sampler->samplerate_offset = sampler->length_offset + sizeof(size_t);
    sampler->channels_offset = sampler->samplerate_offset + sizeof(int);
    sampler->buffer_offset = sampler->channels_offset + sizeof(int);

    sampler->buf = mmap(NULL, sampler->total_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, sampler->fd, 0);
    if(sampler->buf == MAP_FAILED) {
        perror("lpadc_open: Could not mmap sampler.\n");
        return NULL;
    }

    if(lpsampler_get_length(sampler, &sampler->length) == -1) {
        perror("Could not read sampler length from shm\n");
        return NULL;
    }

    if(lpsampler_get_samplerate(sampler, &sampler->samplerate) == -1) {
        perror("Could not read sampler samplerate from shm\n");
        return NULL;
    }

    if(lpsampler_get_channels(sampler, &sampler->channels) == -1) {
        perror("Could not read sampler channels from shm\n");
        return NULL;
    }

    tmpbuf = LPBuffer.create(buf->length, buf->channels, buf->samplerate);
    LPBuffer.copy(buf, tmpbuf);
    memcpy(tmpbuf->data, sampler->buf+sampler->buffer_offset, sizeof(lpfloat_t) * sampler->length);
    LPBuffer.dub(tmpbuf, buf, 0);
    memcpy(sampler->buf+sampler->buffer_offset, tmpbuf->data, sizeof(lpfloat_t) * sampler->length);
    LPBuffer.destroy(tmpbuf);
    return sampler;
}

lpfloat_t lpsampler_read_sample(lpsampler_t * sampler, size_t frame, int channel) {
    lpfloat_t sample;
    size_t offset;
    size_t length = 0;
    int channels = 0;

    // get buf channels
    lpsampler_get_channels(sampler, &channels);
    lpsampler_get_length(sampler, &length);

    frame = frame % length;

    // get offset to buf
    offset = sampler->buffer_offset;
    offset += ((frame * channels + channel) * sizeof(lpfloat_t));

    // memcpy at offset to lpfloat_t
    sample = 0;
    memcpy(&sample, sampler->buf+offset, sizeof(lpfloat_t));

    return sample;
}

int lpsampler_close(lpsampler_t * sampler) {
    if(close(sampler->fd) == -1) {
        perror("Could not close sampler fd.\n");
        return -1;
    }
    return 0;
}

int lpsampler_destroy(lpsampler_t * sampler) {
    if(shm_unlink(sampler->name) == -1) {
        perror("Could not unlink sampler fd.\n");
        return -1;
    }
    free(sampler->name);
    free(sampler);
    return 0;
}

int lpadc_get_pos(lpadcbuf_t * adcbuf, size_t * pos) {
    struct flock fl;
    fl.l_type = F_RDLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = adcbuf->pos_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a lock on adcbuf pos lock.\n");
        return -1;
    } else {
        memcpy(pos, adcbuf->buf+adcbuf->pos_offset, sizeof(size_t));

        fl.l_type = F_UNLCK;
        if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock adcbuf pos lock.\n");
            return -1;
        }
    }

    return 0;
}

int lpadc_set_pos(lpadcbuf_t * adcbuf, size_t pos) {
    struct flock fl;
    fl.l_type = F_WRLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = adcbuf->pos_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a read lock on adcbuf pos.\n");
        return -1;
    } else {
        memcpy(adcbuf->buf+adcbuf->pos_offset, &pos, sizeof(size_t));

        fl.l_type = F_UNLCK;
        if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock read lock adcbuf pos.\n");
            return -1;
        }
    }

    return 0;
}

size_t lpadc_get_length(lpadcbuf_t * adcbuf) {
    size_t length;
    struct flock fl;
    fl.l_type = F_RDLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = adcbuf->length_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a read lock on adcbuf length.\n");
        return -1;
    } else {
        memcpy(&length, adcbuf->buf+adcbuf->length_offset, sizeof(size_t));

        fl.l_type = F_UNLCK;
        if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock adcbuf length read lock.\n");
            return -1;
        }
    }

    return length;
}

int lpadc_set_length(lpadcbuf_t * adcbuf, size_t length) {
    struct flock fl;
    fl.l_type = F_WRLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = adcbuf->length_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a write lock on adcbuf length.\n");
        return -1;
    } else {
        memcpy(adcbuf->buf+adcbuf->length_offset, &length, sizeof(size_t));

        fl.l_type = F_UNLCK;
        if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock write lock adcbuf length.\n");
            return -1;
        }
    }

    return 0;
}

int lpadc_get_channels(lpadcbuf_t * adcbuf) {
    int channels;
    struct flock fl;
    fl.l_type = F_RDLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = adcbuf->channels_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a read lock on adcbuf channels.\n");
        return -1;
    } else {
        memcpy(&channels, adcbuf->buf+adcbuf->channels_offset, sizeof(int));

        fl.l_type = F_UNLCK;
        if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock adcbuf channel read lock.\n");
            return -1;
        }
    }

    return channels;
}

int lpadc_set_channels(lpadcbuf_t * adcbuf, int channels) {
    struct flock fl;
    fl.l_type = F_WRLCK;
    fl.l_whence = SEEK_SET;
    fl.l_start = adcbuf->channels_offset;
    fl.l_len = sizeof(size_t);

    if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
        perror("Could not aquire a write lock on adcbuf channels.\n");
        return -1;
    } else {
        memcpy(adcbuf->buf+adcbuf->channels_offset, &channels, sizeof(int));

        fl.l_type = F_UNLCK;
        if(fcntl(adcbuf->fd, F_SETLK, &fl) == -1) {
            perror("Could not unlock write lock adcbuf channels.\n");
            return -1;
        }
    }

    return 0;
}

lpadcbuf_t * lpadc_create() {
    lpadcbuf_t * adcbuf;

    // this struct holds a reference to the shared memory buffer
    // and metadata deserialized from the shared memory buffer
    adcbuf = (lpadcbuf_t *)calloc(sizeof(lpadcbuf_t), 1);

    // open the shared memory buffer and store the file descriptor
    adcbuf->fd = shm_open(LPADC_BUFNAME, O_CREAT | O_EXCL | O_RDWR, S_IRUSR | S_IWUSR);
    if(adcbuf->fd == -1) {
        perror("Could not get a handle to adcbuf shared memory.\n");
        return NULL;
    }

    /* FIXME get samplerate & channels from context */
    // set general metadata
    adcbuf->length = (size_t)(ASTRID_ADCSECONDS * ASTRID_SAMPLERATE);
    adcbuf->channels = ASTRID_CHANNELS;
    adcbuf->buffer_offset = sizeof(size_t) + sizeof(size_t) + sizeof(int);
    adcbuf->pos = 0;

    /* Store byte offsets for easy lookup */
    // FIXME most of these offsets could probably be constants...
    adcbuf->pos_offset = 0;
    adcbuf->length_offset = adcbuf->pos_offset + sizeof(size_t);
    adcbuf->channels_offset = adcbuf->length_offset + sizeof(size_t);
    adcbuf->buffer_offset = adcbuf->channels_offset + sizeof(int);
    adcbuf->total_bytes = adcbuf->buffer_offset + (sizeof(lpfloat_t) * adcbuf->length * adcbuf->channels);

    // Initialize the shared memory buffer to the appropriate size
    if(ftruncate(adcbuf->fd, adcbuf->total_bytes) == -1) {
        perror("Could not resize adcbuf.\n");
        return NULL;
    }

    // mmap the shared memory to the char * pointer
    // opening it for reading and writing
    adcbuf->buf = mmap(NULL, adcbuf->total_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, adcbuf->fd, 0);
    if(adcbuf->buf == MAP_FAILED) {
        perror("Could not mmap adcbuf.\n");
        return NULL;
    }

    // initialize pos, length and channels values in the shared memory buffer
    memcpy(adcbuf->buf+adcbuf->pos_offset, &adcbuf->pos, sizeof(size_t));
    memcpy(adcbuf->buf+adcbuf->length_offset, &adcbuf->length, sizeof(size_t));
    memcpy(adcbuf->buf+adcbuf->channels_offset, &adcbuf->channels, sizeof(int));

    // return a pointer to the struct
    return adcbuf;
}

lpadcbuf_t * lpadc_open() {
    lpadcbuf_t * adcbuf;
    struct stat buffdstat;

    adcbuf = (lpadcbuf_t *)calloc(sizeof(lpadcbuf_t), 1);
    adcbuf->fd = shm_open(LPADC_BUFNAME, O_RDONLY, 0);
    if(adcbuf->fd == -1) {
        perror("lpadc_open: Could not open a handle to adcbuf shared memory.\n");
        return NULL;
    }

    /* fstat check size */
    if(fstat(adcbuf->fd, &buffdstat) == -1) {
        perror("lpadc_open: Could not fstat adcbuf shared memory.\n");
        return NULL;
    }

    adcbuf->total_bytes = buffdstat.st_size;

    adcbuf->buf = mmap(NULL, adcbuf->total_bytes, PROT_READ, MAP_SHARED, adcbuf->fd, 0);
    if(adcbuf->buf == MAP_FAILED) {
        perror("lpadc_open: Could not mmap adcbuf.\n");
        return NULL;
    }


    /* Store byte offsets for easy lookup */
    adcbuf->pos_offset = 0;
    adcbuf->length_offset = adcbuf->pos_offset + sizeof(size_t);
    adcbuf->channels_offset = adcbuf->length_offset + sizeof(size_t);
    adcbuf->buffer_offset = adcbuf->channels_offset + sizeof(int);

    lpadc_get_pos(adcbuf, &adcbuf->pos);
    adcbuf->channels = lpadc_get_channels(adcbuf);
    adcbuf->length = lpadc_get_length(adcbuf);

    return adcbuf;
}

lpfloat_t lpadc_read_sample(lpadcbuf_t * adcbuf, size_t frame, int channel) {
    lpfloat_t sample;
    size_t offset;
    size_t length = 0;
    int channels = 0;

    // get buf channels
    channels = lpadc_get_channels(adcbuf);
    length = lpadc_get_length(adcbuf);

    frame = frame % length;

    // get offset to buf
    offset = adcbuf->buffer_offset;
    offset += ((frame * channels + channel) * sizeof(lpfloat_t));

    // memcpy at offset to lpfloat_t
    sample = 0;
    memcpy(&sample, adcbuf->buf+offset, sizeof(lpfloat_t));

    return sample;
}

int lpadc_increment_pos(lpadcbuf_t * adcbuf, int count) {
    size_t pos = 0;
    size_t length = 0;

    if(lpadc_get_pos(adcbuf, &pos) == -1) return -1;
    length = lpadc_get_length(adcbuf);
    pos = (pos + count) % length;

    return lpadc_set_pos(adcbuf, pos);
}

size_t lpadc_write_sample(
        lpadcbuf_t * adcbuf, 
        lpfloat_t sample, 
        size_t frame, 
        int channel, 
        ssize_t offset
) {
    size_t writepos;
    size_t length;
    int channels;

    channels = lpadc_get_channels(adcbuf);
    length = lpadc_get_length(adcbuf);

    assert(length != 0);

    frame = (frame + offset) % length;
    writepos = adcbuf->buffer_offset + (((frame * channels) + channel) * sizeof(lpfloat_t));
    memcpy(adcbuf->buf + writepos, &sample, sizeof(lpfloat_t));

    return frame;
}

int lpadc_close(lpadcbuf_t * adcbuf) {
    if(close(adcbuf->fd) == -1) {
        perror("Could not close adcbuf fd.\n");
        return -1;
    }
    return 0;
}

int lpadc_destroy(lpadcbuf_t * adcbuf) {
    if(shm_unlink(LPADC_BUFNAME) == -1) {
        perror("Could not unlink adcbuf fd.\n");
        return -1;
    }
    free(adcbuf);
    return 0;
}

char * serialize_buffer(lpbuffer_t * buf, char * instrument_name, char * play_params) {
    size_t strsize, audiosize, offset, namesize, paramsize;
    char * str;

    audiosize = buf->length * buf->channels * sizeof(lpfloat_t);
    namesize = strlen(instrument_name);
    paramsize = strlen(play_params);

    strsize =  0;
    strsize += sizeof(size_t); /* length     */
    strsize += sizeof(size_t); /* namelen    */
    strsize += sizeof(size_t); /* paramlen    */
    strsize += sizeof(int);    /* channels   */
    strsize += sizeof(int);    /* samplerate */
    strsize += sizeof(int);    /* is_looping */
    strsize += sizeof(size_t); /* onset      */
    strsize += audiosize;      /* audio data */
    strsize += namesize;       /* instrument_name */
    strsize += paramsize;      /* play_params */

    /* initialize string buffer */
    str = calloc(1, strsize);

    offset = 0;

    memcpy(str + offset, &audiosize, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(str + offset, &namesize, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(str + offset, &paramsize, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(str + offset, &buf->length, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(str + offset, &buf->channels, sizeof(int));
    offset += sizeof(int);

    memcpy(str + offset, &buf->samplerate, sizeof(int));
    offset += sizeof(int);

    memcpy(str + offset, &buf->is_looping, sizeof(int));
    offset += sizeof(int);

    memcpy(str + offset, &buf->onset, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(str + offset, buf->data, audiosize);
    offset += audiosize;

    memcpy(str + offset, instrument_name, namesize);
    offset += namesize;

    memcpy(str + offset, play_params, paramsize);
    offset += paramsize;

    return str;
}

lpbuffer_t * deserialize_buffer(char * str, lpeventctx_t * ctx) {
    size_t audiosize, offset, length, onset, namesize, paramsize;
    int channels, samplerate, is_looping;
    lpbuffer_t * buf;
    lpfloat_t * audio;

    offset = 0;

    memcpy(&audiosize, str + offset, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(&namesize, str + offset, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(&paramsize, str + offset, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(&length, str + offset, sizeof(size_t));
    offset += sizeof(size_t);

    memcpy(&channels, str + offset, sizeof(int));
    offset += sizeof(int);

    memcpy(&samplerate, str + offset, sizeof(int));
    offset += sizeof(int);

    memcpy(&is_looping, str + offset, sizeof(int));
    offset += sizeof(int);

    memcpy(&onset, str + offset, sizeof(size_t));
    offset += sizeof(size_t);

    audio = calloc(1, audiosize);
    memcpy(audio, str + offset, audiosize);
    offset += audiosize;

    memcpy(ctx->instrument_name, str + offset, namesize);
    offset += namesize;

    memcpy(ctx->play_params, str + offset, paramsize);
    offset += paramsize;

    buf = calloc(1, sizeof(lpbuffer_t));

    buf->length = length;
    buf->channels = channels;
    buf->samplerate = samplerate;
    buf->is_looping = is_looping;
    buf->data = audio;
    buf->onset = onset;

    buf->phase = 0.f;
    buf->pos = 0;
    buf->boundry = length-1;
    buf->range = length;

    return buf;
}

// TODO
// - break into: open/create, read, close
// - call open only once in the lifetime of the cb...
int get_play_message(char * instrument_name, lpmsg_t * msg) {
    int qfd;
    ssize_t qname_length;
    char qname[LPMAXQNAME] = {0};
    ssize_t read_result;

    qname_length = snprintf(NULL, 0, "%s-%s", LPPLAYQ, instrument_name) + 1;
    qname_length = (LPMAXQNAME >= qname_length) ? LPMAXQNAME : qname_length;
    snprintf(qname, qname_length, "%s-%s", LPPLAYQ, instrument_name);

    umask(0);
    if(mkfifo(qname, S_IRUSR | S_IWUSR | S_IWGRP) == -1 && errno != EEXIST) {
        perror("Error creating named pipe\n");
        return -1;
    }

    qfd = open(qname, O_RDONLY);
    if((read_result = read(qfd, msg, sizeof(lpmsg_t))) != sizeof(lpmsg_t)) {
        syslog(LOG_INFO, "Play queue for %s has closed\n", instrument_name);
        return -1;
    }

    if(close(qfd) == -1) {
        perror("Error closing q...\n");
        return -1; 
    }

    return 0;
}

int astrid_playq_open(char * instrument_name) {
    int qfd;
    ssize_t qname_length;
    char qname[LPMAXQNAME] = {0};

    qname_length = snprintf(NULL, 0, "%s-%s", LPPLAYQ, instrument_name) + 1;
    qname_length = (LPMAXQNAME >= qname_length) ? LPMAXQNAME : qname_length;
    snprintf(qname, qname_length, "%s-%s", LPPLAYQ, instrument_name);

    umask(0);
    if(mkfifo(qname, S_IRUSR | S_IWUSR | S_IWGRP) == -1 && errno != EEXIST) {
        perror("Error creating play queue FIFO\n");
        return -1;
    }

    if((qfd = open(qname, O_RDWR)) < 0) {
        perror("Error opening play queue FIFO\n");
    };

    return qfd;
}

int astrid_playq_close(int qfd) {
    if(close(qfd) == -1) {
        perror("Error closing q...\n");
        return -1; 
    }

    return 0;
}

int astrid_playq_read(int qfd, lpmsg_t * msg) {
    ssize_t read_result;
    read_result = read(qfd, msg, sizeof(lpmsg_t));
    if(read_result == 0) {
        syslog(LOG_DEBUG, "The play queue (%d) has been closed. (EOF)\n", qfd);
        return -1;
    }

    // do we need larger play messages?
    if(read_result != sizeof(lpmsg_t)) {
        syslog(LOG_INFO, "The play queue (%d) returned %d bytes. Expecting sizeof(lpmsg_t)==%d\n", qfd, (int)read_result, (int)sizeof(lpmsg_t));
        return -1;
    }

    return 0;
}


int send_play_message(lpeventctx_t * ctx) {
    char qname[LPMAXQNAME] = {0};
    ssize_t qname_length;
    lpmsg_t msg = {0};
    int qfd;

    qname_length = snprintf(NULL, 0, "%s-%s", LPPLAYQ, ctx->instrument_name) + 1;
    qname_length = (LPMAXQNAME >= qname_length) ? LPMAXQNAME : qname_length;
    snprintf(qname, qname_length, "%s-%s", LPPLAYQ, ctx->instrument_name);

    umask(0);
    if(mkfifo(qname, S_IRUSR | S_IWUSR | S_IWGRP) == -1 && errno != EEXIST) {
        perror("Error creating named pipe\n");
        return -1;
    }

    qfd = open(qname, O_WRONLY);

    strncpy(msg.msg, ctx->play_params, LPMAXMSG);
    msg.timestamp = 0;

    if(write(qfd, &msg, sizeof(lpmsg_t)) != sizeof(lpmsg_t)) {
        perror("Could not write to q...\n");
        return -1;
    }

    if(close(qfd) == -1) {
        perror("Error closing play q...\n");
        return -1; 
    }

    return 0;
}

