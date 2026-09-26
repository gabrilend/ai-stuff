/*
 * mailbox.h - hands whole states from writers to one reader without either waiting (issue 515c)
 *
 * What this is: the way the engine's answers reach the draw thread. There is
 * one buffer per writer, one for the reader, and one in the middle holding
 * the latest complete state. Each thread holds its own buffer and touches
 * no other; only the middle is shared, named by one atomic word.
 *
 *   writer: fills its buffer, then publishes -- one exchange puts it in the
 *           middle marked fresh and hands the writer whatever was there.
 *   reader: takes -- if the middle is fresh, one exchange swaps the reader's
 *           buffer for it; if not, it keeps what it has.
 *
 * With one writer that's the triple buffer: one being drawn, one latest,
 * one being written. A fresh state nobody took is written over by the next
 * publish, so a newer state replaces a waiting one instead of queueing
 * behind it: no frame of delay is ever added.
 *
 * Why it's safe: a buffer changes hands only through the shared word, and
 * the exchanges are acquire-release. Everything a writer stored is visible
 * to the reader that takes its buffer; everything the reader read of a
 * buffer is finished before a writer is handed that buffer back.
 *
 * One reader only: two readers would take each other's fresh states. Many
 * writers are fine, each with its own buffer.
 *
 * Header only: every function is small and called once a frame.
 */
#ifndef CERAMIC_MAILBOX_H
#define CERAMIC_MAILBOX_H

#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#define MAILBOX_MOST_WRITERS 30
/* The shared word: the middle buffer's number in the low bits, and this bit
 * set when a writer put it there and the reader hasn't taken it yet. */
#define MAILBOX_FRESH 0x80000000u
#define MAILBOX_INDEX 0x7fffffffu

typedef struct {
    size_t         bytes;                          /* one buffer's size */
    int            writers;                        /* buffers = writers + 2 */
    unsigned char *buffers[MAILBOX_MOST_WRITERS + 2];
    unsigned int   writing[MAILBOX_MOST_WRITERS];  /* each writer's own buffer; only that writer touches its entry */
    unsigned int   reading;                        /* the reader's own buffer; only the reader touches it */
    char           apart[64];                      /* keeps the shared word off the cache line the others share */
    _Atomic unsigned int middle;                   /* the middle buffer, and the fresh bit */
} mailbox;

/* {{{ static inline mailbox *mailbox_create(size_t bytes, int writers) */
/* Every buffer zeroed. Writer w starts with buffer w, the middle holds
 * buffer `writers` (not fresh), and the reader holds the last. Returns NULL
 * for a writer count outside 1..MAILBOX_MOST_WRITERS or no memory; the
 * caller refuses to go on. */
static inline mailbox *mailbox_create(size_t bytes, int writers)
{
    if (writers < 1 || writers > MAILBOX_MOST_WRITERS) return NULL;
    mailbox *mb = calloc(1, sizeof *mb);
    if (!mb) return NULL;
    mb->bytes = bytes;
    mb->writers = writers;
    for (int b = 0; b < writers + 2; b++) {
        /* each buffer on its own cache lines, so two threads never share one */
        mb->buffers[b] = aligned_alloc(64, (bytes + 63) / 64 * 64);
        if (!mb->buffers[b]) return NULL;
        memset(mb->buffers[b], 0, bytes);
    }
    for (int w = 0; w < writers; w++) mb->writing[w] = (unsigned int)w;
    atomic_init(&mb->middle, (unsigned int)writers);
    mb->reading = (unsigned int)writers + 1;
    return mb;
}
/* }}} */

/* {{{ static inline void *mailbox_writing(mailbox *mb, int writer) */
/* The buffer this writer fills next. It stays this writer's until it
 * publishes. */
static inline void *mailbox_writing(mailbox *mb, int writer)
{
    return mb->buffers[mb->writing[writer]];
}
/* }}} */

/* {{{ static inline void mailbox_publish(mailbox *mb, int writer) */
/* The writer's buffer is complete: it becomes the latest, and the writer is
 * handed the old middle to write next -- a state the reader never took, or
 * the one it let go of. */
static inline void mailbox_publish(mailbox *mb, int writer)
{
    unsigned int was = atomic_exchange_explicit(&mb->middle, mb->writing[writer] | MAILBOX_FRESH, memory_order_acq_rel);
    mb->writing[writer] = was & MAILBOX_INDEX;
}
/* }}} */

/* {{{ static inline const void *mailbox_take(mailbox *mb, int *is_new) */
/* The buffer to draw. Two paths:
 *   the middle is fresh -> swap it for the reader's buffer; *is_new = 1
 *   it isn't            -> keep the reader's buffer (drawn again); *is_new = 0
 * The glance before the exchange is safe because writers only ever set the
 * fresh bit; only this, the one reader, clears it. */
static inline const void *mailbox_take(mailbox *mb, int *is_new)
{
    *is_new = 0;
    if (atomic_load_explicit(&mb->middle, memory_order_relaxed) & MAILBOX_FRESH) {
        unsigned int was = atomic_exchange_explicit(&mb->middle, mb->reading, memory_order_acq_rel);
        mb->reading = was & MAILBOX_INDEX;
        *is_new = 1;
    }
    return mb->buffers[mb->reading];
}
/* }}} */

/* {{{ static inline void mailbox_destroy(mailbox *mb) */
static inline void mailbox_destroy(mailbox *mb)
{
    for (int b = 0; b < mb->writers + 2; b++) free(mb->buffers[b]);
    free(mb);
}
/* }}} */

#endif
