/*
 * html_gen.c - Parallel HTML file writer using pthreads
 *
 * Implements a thread pool for parallel file writing. Each worker thread
 * grabs files from a shared queue using atomic operations for load balancing.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>
#include <sys/time.h>
#include <errno.h>
#include <sys/stat.h>
#include <libgen.h>

#include "html_gen.h"

/* {{{ Constants */
#define INITIAL_CAPACITY 1024
#define MAX_PATH_LEN 4096
/* }}} */

/* {{{ File entry structure */
typedef struct {
    char* filepath;
    char* content;
    size_t content_len;
} FileEntry;
/* }}} */

/* {{{ Context structure */
struct HtmlGenContext {
    /* Thread pool */
    int num_threads;
    pthread_t* threads;
    int threads_running;

    /* File queue */
    FileEntry* files;
    uint32_t file_count;
    uint32_t file_capacity;

    /* Work distribution (atomic for lock-free access) */
    atomic_uint work_index;
    atomic_uint files_written;
    atomic_uint files_failed;
    atomic_ulong bytes_written;

    /* Timing */
    struct timeval start_time;
    struct timeval end_time;

    /* State */
    int is_running;
};
/* }}} */

/* {{{ Forward declarations */
static void* worker_thread(void* arg);
static int ensure_directory(const char* filepath);
/* }}} */

/* {{{ htmlgen_init */
HtmlGenContext* htmlgen_init(int num_threads) {
    HtmlGenContext* ctx = calloc(1, sizeof(HtmlGenContext));
    if (!ctx) return NULL;

    /* Auto-detect CPU cores if num_threads is 0 */
    if (num_threads <= 0) {
        num_threads = sysconf(_SC_NPROCESSORS_ONLN);
        if (num_threads <= 0) num_threads = 4;
    }

    ctx->num_threads = num_threads;
    ctx->threads = calloc(num_threads, sizeof(pthread_t));
    if (!ctx->threads) {
        free(ctx);
        return NULL;
    }

    /* Initialize file queue */
    ctx->file_capacity = INITIAL_CAPACITY;
    ctx->files = calloc(ctx->file_capacity, sizeof(FileEntry));
    if (!ctx->files) {
        free(ctx->threads);
        free(ctx);
        return NULL;
    }

    ctx->file_count = 0;
    ctx->threads_running = 0;
    ctx->is_running = 0;

    /* Initialize atomics */
    atomic_init(&ctx->work_index, 0);
    atomic_init(&ctx->files_written, 0);
    atomic_init(&ctx->files_failed, 0);
    atomic_init(&ctx->bytes_written, 0);

    return ctx;
}
/* }}} */

/* {{{ htmlgen_add_file */
HtmlGenResult htmlgen_add_file(HtmlGenContext* ctx,
                                const char* filepath,
                                const char* content,
                                size_t content_len) {
    if (!ctx) return HTMLGEN_ERROR_INVALID_CONTEXT;
    if (ctx->is_running) return HTMLGEN_ERROR_ALREADY_RUNNING;

    /* Grow array if needed */
    if (ctx->file_count >= ctx->file_capacity) {
        uint32_t new_capacity = ctx->file_capacity * 2;
        FileEntry* new_files = realloc(ctx->files, new_capacity * sizeof(FileEntry));
        if (!new_files) return HTMLGEN_ERROR_OUT_OF_MEMORY;
        ctx->files = new_files;
        ctx->file_capacity = new_capacity;
    }

    /* Copy filepath */
    FileEntry* entry = &ctx->files[ctx->file_count];
    entry->filepath = strdup(filepath);
    if (!entry->filepath) return HTMLGEN_ERROR_OUT_OF_MEMORY;

    /* Copy content */
    entry->content = malloc(content_len + 1);
    if (!entry->content) {
        free(entry->filepath);
        return HTMLGEN_ERROR_OUT_OF_MEMORY;
    }
    memcpy(entry->content, content, content_len);
    entry->content[content_len] = '\0';
    entry->content_len = content_len;

    ctx->file_count++;
    return HTMLGEN_SUCCESS;
}
/* }}} */

/* {{{ ensure_directory - Create parent directories if needed */
static int ensure_directory(const char* filepath) {
    char* path_copy = strdup(filepath);
    if (!path_copy) return -1;

    char* dir = dirname(path_copy);

    /* Check if directory exists */
    struct stat st;
    if (stat(dir, &st) == 0 && S_ISDIR(st.st_mode)) {
        free(path_copy);
        return 0;
    }

    /* Create directory (and parents) */
    char cmd[MAX_PATH_LEN + 16];
    snprintf(cmd, sizeof(cmd), "mkdir -p '%s'", dir);
    int ret = system(cmd);

    free(path_copy);
    return ret;
}
/* }}} */

/* {{{ worker_thread - Thread function for parallel file writing */
static void* worker_thread(void* arg) {
    HtmlGenContext* ctx = (HtmlGenContext*)arg;

    while (1) {
        /* Atomically grab next work item */
        uint32_t index = atomic_fetch_add(&ctx->work_index, 1);

        /* Check if we're done */
        if (index >= ctx->file_count) {
            break;
        }

        FileEntry* entry = &ctx->files[index];

        /* Ensure parent directory exists */
        if (ensure_directory(entry->filepath) != 0) {
            atomic_fetch_add(&ctx->files_failed, 1);
            continue;
        }

        /* Write file */
        FILE* f = fopen(entry->filepath, "w");
        if (!f) {
            atomic_fetch_add(&ctx->files_failed, 1);
            continue;
        }

        size_t written = fwrite(entry->content, 1, entry->content_len, f);
        fclose(f);

        if (written == entry->content_len) {
            atomic_fetch_add(&ctx->files_written, 1);
            atomic_fetch_add(&ctx->bytes_written, written);
        } else {
            atomic_fetch_add(&ctx->files_failed, 1);
        }
    }

    return NULL;
}
/* }}} */

/* {{{ htmlgen_write_all */
HtmlGenResult htmlgen_write_all(HtmlGenContext* ctx) {
    if (!ctx) return HTMLGEN_ERROR_INVALID_CONTEXT;
    if (ctx->is_running) return HTMLGEN_ERROR_ALREADY_RUNNING;
    if (ctx->file_count == 0) return HTMLGEN_SUCCESS;

    ctx->is_running = 1;

    /* Reset counters */
    atomic_store(&ctx->work_index, 0);
    atomic_store(&ctx->files_written, 0);
    atomic_store(&ctx->files_failed, 0);
    atomic_store(&ctx->bytes_written, 0);

    /* Record start time */
    gettimeofday(&ctx->start_time, NULL);

    /* Spawn worker threads */
    for (int i = 0; i < ctx->num_threads; i++) {
        if (pthread_create(&ctx->threads[i], NULL, worker_thread, ctx) != 0) {
            /* Thread creation failed - wait for already-started threads */
            for (int j = 0; j < i; j++) {
                pthread_join(ctx->threads[j], NULL);
            }
            ctx->is_running = 0;
            return HTMLGEN_ERROR_INIT_FAILED;
        }
    }
    ctx->threads_running = ctx->num_threads;

    /* Wait for all threads to complete */
    for (int i = 0; i < ctx->num_threads; i++) {
        pthread_join(ctx->threads[i], NULL);
    }

    /* Record end time */
    gettimeofday(&ctx->end_time, NULL);

    ctx->threads_running = 0;
    ctx->is_running = 0;

    /* Check for failures */
    if (atomic_load(&ctx->files_failed) > 0) {
        return HTMLGEN_ERROR_WRITE_FAILED;
    }

    return HTMLGEN_SUCCESS;
}
/* }}} */

/* {{{ htmlgen_get_progress */
float htmlgen_get_progress(HtmlGenContext* ctx) {
    if (!ctx || ctx->file_count == 0) return 0.0f;

    uint32_t completed = atomic_load(&ctx->files_written) +
                         atomic_load(&ctx->files_failed);
    return (float)completed / (float)ctx->file_count;
}
/* }}} */

/* {{{ htmlgen_get_stats */
HtmlGenResult htmlgen_get_stats(HtmlGenContext* ctx, HtmlGenStats* stats) {
    if (!ctx) return HTMLGEN_ERROR_INVALID_CONTEXT;
    if (!stats) return HTMLGEN_ERROR_INVALID_CONTEXT;

    stats->total_files = ctx->file_count;
    stats->files_written = atomic_load(&ctx->files_written);
    stats->files_failed = atomic_load(&ctx->files_failed);
    stats->total_bytes = atomic_load(&ctx->bytes_written);

    /* Calculate elapsed time */
    double start = ctx->start_time.tv_sec + ctx->start_time.tv_usec / 1000000.0;
    double end = ctx->end_time.tv_sec + ctx->end_time.tv_usec / 1000000.0;
    stats->elapsed_seconds = end - start;

    return HTMLGEN_SUCCESS;
}
/* }}} */

/* {{{ htmlgen_clear */
void htmlgen_clear(HtmlGenContext* ctx) {
    if (!ctx) return;

    /* Free all file entries */
    for (uint32_t i = 0; i < ctx->file_count; i++) {
        free(ctx->files[i].filepath);
        free(ctx->files[i].content);
    }

    ctx->file_count = 0;

    /* Reset counters */
    atomic_store(&ctx->work_index, 0);
    atomic_store(&ctx->files_written, 0);
    atomic_store(&ctx->files_failed, 0);
    atomic_store(&ctx->bytes_written, 0);
}
/* }}} */

/* {{{ htmlgen_destroy */
void htmlgen_destroy(HtmlGenContext* ctx) {
    if (!ctx) return;

    /* Free all file entries */
    for (uint32_t i = 0; i < ctx->file_count; i++) {
        free(ctx->files[i].filepath);
        free(ctx->files[i].content);
    }

    free(ctx->files);
    free(ctx->threads);
    free(ctx);
}
/* }}} */

/* {{{ htmlgen_error_string */
const char* htmlgen_error_string(HtmlGenResult result) {
    switch (result) {
        case HTMLGEN_SUCCESS:
            return "Success";
        case HTMLGEN_ERROR_INIT_FAILED:
            return "Initialization failed";
        case HTMLGEN_ERROR_OUT_OF_MEMORY:
            return "Out of memory";
        case HTMLGEN_ERROR_WRITE_FAILED:
            return "File write failed";
        case HTMLGEN_ERROR_INVALID_CONTEXT:
            return "Invalid context";
        case HTMLGEN_ERROR_ALREADY_RUNNING:
            return "Already running";
        default:
            return "Unknown error";
    }
}
/* }}} */
