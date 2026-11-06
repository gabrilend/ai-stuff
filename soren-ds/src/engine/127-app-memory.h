/*
 * 127-app-memory.h — memory that belongs to one app (the shape of issue
 * 902, as a STAND-IN).
 *
 * General description: an app's own data — the modeller's vertex grid
 * first — is taken through these calls, naming the app it is for, so
 * that when 902 gives every app a region of its own the callers do not
 * change. Until then this is a STAND-IN: the memory comes from the
 * engine's shared block allocator (029), exactly as the engine's own
 * memory does, and nothing stops one app's bad write landing in
 * another's. What the stand-in does keep is the region's other half, its
 * size: each app has a budget, and a request that would take it past the
 * budget is refused, as a full region would refuse it.
 *
 * An app is named by a number below APP_MEMORY_APPS. Until 902 says what
 * an app's handle is, the caller chooses it (the modeller's tests use the
 * number of the program they loaded).
 */
#ifndef SOREN_APP_MEMORY_H
#define SOREN_APP_MEMORY_H

#include <stdint.h>
#include <stddef.h>

#define APP_MEMORY_APPS          64
#define APP_MEMORY_DEFAULT_LIMIT ((size_t)4 << 20)      /* "a few megabytes per app" (902) */

/* `bytes` of zeroed memory for `app`, or NULL: a bad app number, a
 * request past the app's budget, or the pool itself empty. */
void  *app_memory_alloc(int app, size_t bytes);
/* Give it back; `bytes` is what was asked for. */
void   app_memory_free(int app, void *memory, size_t bytes);

/* Bytes the app holds now, and its budget. A budget may be set below
 * what is held: nothing is taken back, but nothing more is given. */
size_t app_memory_held(int app);
size_t app_memory_limit(int app);
void   app_memory_set_limit(int app, size_t bytes);

struct app_memory_counts {
    uint64_t taken, given_back, refused;
};
struct app_memory_counts app_memory_counts(int app);

#endif
