/*
 * 026-platform-twin.h — the laptop's own setup calls, before the portable
 * code starts asking questions.
 *
 * General description: on the handheld, how many cores there are and how
 * big the memory pool is are facts of the silicon. On the laptop they are
 * choices, made once by whichever twin program is starting up, before it
 * calls anything in the engine. These are those choices.
 */
#ifndef SOREN_PLATFORM_TWIN_H
#define SOREN_PLATFORM_TWIN_H

#include <stddef.h>
#include <stdint.h>

/* Choose the number of cores (1 .. PLATFORM_MAX_CORES) and the size of the
 * memory pool in bytes (rounded up to whole 2 MB stripes). Must be called
 * exactly once, before any other platform call. The pool is one anonymous
 * mapping, aligned to 2 MB like the device's. */
void twin_platform_init(int cores, size_t pool_bytes);

/* Where platform_write sends its text besides standard output: a file path,
 * or NULL for standard output alone. Standard output can also be silenced,
 * for tests that produce a great deal of expected chatter. */
void twin_platform_set_log(const char *path, int also_stdout);

/* Use this disk-image file as the SD card. It must already be formatted
 * (scripts/make-card-image makes one). */
void twin_card_open(const char *path);

/* Give the memory pool back. Only the twin ever does this. */
void twin_platform_shutdown(void);

/* How many times a screen has been presented (a finished frame). */
uint64_t twin_screen_presents(int which);

#endif
