/*
 * html_gen.h - Parallel HTML file writer using pthreads
 *
 * This library provides thread-pooled file writing for HTML generation.
 * Lua generates the HTML strings, C handles parallel I/O.
 *
 * Usage:
 *   1. Create context with htmlgen_init(num_threads)
 *   2. Add files with htmlgen_add_file(ctx, path, content, content_len)
 *   3. Write all files with htmlgen_write_all(ctx)
 *   4. Check progress with htmlgen_get_progress(ctx)
 *   5. Cleanup with htmlgen_destroy(ctx)
 */

#ifndef HTML_GEN_H
#define HTML_GEN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* {{{ Opaque context handle */
typedef struct HtmlGenContext HtmlGenContext;
/* }}} */

/* {{{ Error codes */
typedef enum {
    HTMLGEN_SUCCESS = 0,
    HTMLGEN_ERROR_INIT_FAILED = -1,
    HTMLGEN_ERROR_OUT_OF_MEMORY = -2,
    HTMLGEN_ERROR_WRITE_FAILED = -3,
    HTMLGEN_ERROR_INVALID_CONTEXT = -4,
    HTMLGEN_ERROR_ALREADY_RUNNING = -5,
} HtmlGenResult;
/* }}} */

/* {{{ Statistics structure */
typedef struct {
    uint32_t total_files;
    uint32_t files_written;
    uint32_t files_failed;
    uint64_t total_bytes;
    double elapsed_seconds;
} HtmlGenStats;
/* }}} */

/* {{{ Core API */

/*
 * Initialize HTML generator context
 * @param num_threads Number of worker threads (0 = auto-detect CPU cores)
 * @return Context handle or NULL on failure
 */
HtmlGenContext* htmlgen_init(int num_threads);

/*
 * Add a file to the write queue
 * @param ctx Context handle
 * @param filepath Full path to output file
 * @param content HTML content to write
 * @param content_len Length of content in bytes
 * @return HTMLGEN_SUCCESS or error code
 *
 * Note: Content is copied internally, caller can free after this returns
 */
HtmlGenResult htmlgen_add_file(HtmlGenContext* ctx,
                                const char* filepath,
                                const char* content,
                                size_t content_len);

/*
 * Write all queued files using thread pool
 * Blocks until all files are written
 * @param ctx Context handle
 * @return HTMLGEN_SUCCESS or error code
 */
HtmlGenResult htmlgen_write_all(HtmlGenContext* ctx);

/*
 * Get current progress (0.0 to 1.0)
 * Can be called from another thread while write_all is running
 * @param ctx Context handle
 * @return Progress as fraction (0.0 = not started, 1.0 = complete)
 */
float htmlgen_get_progress(HtmlGenContext* ctx);

/*
 * Get statistics after write_all completes
 * @param ctx Context handle
 * @param stats Output statistics structure
 * @return HTMLGEN_SUCCESS or error code
 */
HtmlGenResult htmlgen_get_stats(HtmlGenContext* ctx, HtmlGenStats* stats);

/*
 * Clear the file queue (reuse context for another batch)
 * @param ctx Context handle
 */
void htmlgen_clear(HtmlGenContext* ctx);

/*
 * Destroy context and free all resources
 * @param ctx Context handle
 */
void htmlgen_destroy(HtmlGenContext* ctx);

/*
 * Get human-readable error string
 * @param result Error code
 * @return Static string describing the error
 */
const char* htmlgen_error_string(HtmlGenResult result);

/* }}} */

#ifdef __cplusplus
}
#endif

#endif /* HTML_GEN_H */
