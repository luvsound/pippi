#include <signal.h>
#include <sys/syscall.h>

#include "cyrenderer.h"
#include "astrid.h"


static volatile int astrid_is_running = 1;
int astrid_channels = 2;
char * instrument_fullpath; /* eg ../orc/ding.py */
char * instrument_basename; /* eg ding           */

void handle_shutdown(int) {
    astrid_is_running = 0;
}

int main() {
    struct sigaction shutdown_action;

    char * _instrument_fullpath; 
    char * _instrument_basename; 
    size_t instrument_name_length;
    char * astrid_pythonpath_env;
    size_t astrid_pythonpath_length;
    wchar_t * python_path;
    size_t msglength = LPMAXMSG;

    char * _astrid_channels;
    lpastridctx_t * ctx;
    PyObject * pmodule;

    openlog("astrid-renderer", LOG_PID, LOG_USER);

    int playqfd = -1;
    lpmsg_t msg = {0};

    syslog(LOG_INFO, "Starting renderer...\n");

    /* Setup sigint handler for graceful shutdown */
    shutdown_action.sa_handler = handle_shutdown;
    sigemptyset(&shutdown_action.sa_mask);
    shutdown_action.sa_flags = 0;
    if(sigaction(SIGINT, &shutdown_action, NULL) == -1) {
        syslog(LOG_ERR, "Could not init SIGINT signal handler.\n");
        exit(1);
    }

    if(sigaction(SIGTERM, &shutdown_action, NULL) == -1) {
        syslog(LOG_ERR, "Could not init SIGTERM signal handler.\n");
        exit(1);
    }

    /* Get python path from env */
    astrid_pythonpath_env = getenv("ASTRID_PYTHONPATH");
    astrid_pythonpath_length = mbstowcs(NULL, astrid_pythonpath_env, 0);
    python_path = calloc(astrid_pythonpath_length+1, sizeof(*python_path));
    if(python_path == NULL) {
        syslog(LOG_ERR, "Error: could not allocate memory for wide char path\n");
        exit(1);
    }

    if(mbstowcs(python_path, astrid_pythonpath_env, astrid_pythonpath_length) == (size_t) -1) {
        syslog(LOG_ERR, "Error: Could not convert path to wchar_t\n");
        exit(1);
    }

    /* Set channels from env */
    _astrid_channels = getenv("ASTRID_CHANNELS");
    if(_astrid_channels != NULL) {
        astrid_channels = atoi(_astrid_channels);
    }
    astrid_channels = 2;

    /* Setup context */
    ctx = (lpastridctx_t*)LPMemoryPool.alloc(1, sizeof(lpastridctx_t));
    ctx->channels = astrid_channels;
    ctx->samplerate = ASTRID_SAMPLERATE;
    ctx->is_playing = 1;
    ctx->is_looping = 1;
    ctx->voice_index = -1;

    /* TODO some human readable ID is useful too? */
    ctx->voice_id = (long)syscall(SYS_gettid);

    /* Set python path */
    /*printf("Setting renderer embedded python path: %ls\n", python_path);*/
    Py_SetPath(python_path);

    /* Prepare cyrenderer module for import */
    if(PyImport_AppendInittab("cyrenderer", PyInit_cyrenderer) == -1) {
        syslog(LOG_ERR, "Error: could not extend in-built modules table for renderer\n");
        exit(1);
    }

    /* Set python program name */
    Py_SetProgramName(L"astrid-renderer");

    /* Init python interpreter */
    Py_InitializeEx(0);

    /* Check renderer python path */
    /*printf("Renderer embedded python path: %ls\n", Py_GetPath());*/

    /* Import cyrenderer */
    pmodule = PyImport_ImportModule("cyrenderer");
    if(!pmodule) {
        PyErr_Print();
        syslog(LOG_ERR, "Error: could not import cython renderer module\n");
        goto lprender_cleanup;
    }

    /* Import python instrument module */
    if(astrid_load_instrument() < 0) {
        PyErr_Print();
        syslog(LOG_ERR, "Error while attempting to load astrid instrument\n");
        goto lprender_cleanup;
    }

    _instrument_fullpath = getenv("INSTRUMENT_PATH");
    _instrument_basename = getenv("INSTRUMENT_NAME");
    instrument_name_length = strlen(_instrument_basename);
    instrument_fullpath = calloc(strlen(_instrument_fullpath)+1, sizeof(char));
    instrument_basename = calloc(instrument_name_length+1, sizeof(char));
    strcpy(instrument_fullpath, _instrument_fullpath);
    strcpy(instrument_basename, _instrument_basename);

    syslog(LOG_INFO, "Astrid renderer... is now rendering!\n");

    playqfd = astrid_playq_open(instrument_basename);
    syslog(LOG_DEBUG, "Opened play queue for %s with fd %d\n", instrument_basename, playqfd);

    /* Start rendering! */
    while(astrid_is_running) {
        memset(msg.msg, 0, LPMAXMSG);

        if(astrid_playq_read(playqfd, &msg) < 0) {
            syslog(LOG_ERR, "Got errno (%d) while fetching message during renderer loop: %s\n", errno, strerror(errno));
            goto lprender_cleanup;
        }

        msg.timestamp = 0;
        /*fprintf(stderr, "Got play msg: %s\n", msg.msg);*/

        if(astrid_tick(msg.msg, &msglength, &msg.timestamp) < 0) {
            PyErr_Print();
            syslog(LOG_ERR, "CPython error during renderer loop\n");
            goto lprender_cleanup;
        }
    }

lprender_cleanup:
    syslog(LOG_INFO, "Astrid renderer shutting down...\n");
    Py_Finalize();
    if(playqfd != -1) astrid_playq_close(playqfd);
    closelog();
    return 0;
}

