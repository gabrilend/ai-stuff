/*
 * 071-transcript.c — the transcript ring (issue 311).
 *
 * General description: a flat array of fixed-size records and one counter.
 * Writing takes the next number from the counter with one atomic add,
 * fills the slot that number maps to, and stamps the slot with its number
 * last — so a reader who sees a slot's number change while copying knows
 * the copy is torn and skips it. Nothing waits, nothing allocates, and the
 * oldest entry is simply overwritten when the counter comes round.
 */
#include "025-platform.h"
#include "027-primitives.h"
#include "071-transcript.h"

#ifdef SOREN_DEBUG
static struct transcript_event ring[TRANSCRIPT_ENTRIES];
static uint64_t counter;
static int      live;
static uint64_t drained_to = 1;
static spin_lock_t drain_lock = SPIN_LOCK_INIT;

/* {{{ transcript_record */
void transcript_record(int kind, int32_t station, int32_t a, int32_t b, int64_t c, const char *note)
{
    uint64_t sequence = atomic_add(&counter, 1);
    struct transcript_event *e = &ring[(sequence - 1) % TRANSCRIPT_ENTRIES];
    atomic_store_relaxed(&e->sequence, 0);         /* being rewritten: readers skip it */
    __atomic_thread_fence(__ATOMIC_RELEASE);
    e->when_ns = platform_now_ns();
    e->kind = (uint16_t)kind;
    e->core = (int16_t)platform_core_id();
    e->station = station;
    e->a = a;
    e->b = b;
    e->c = c;
    int i = 0;
    if (note) {
        for (; note[i] && i < (int)sizeof e->note - 1; i++) e->note[i] = note[i];
    }
    e->note[i] = 0;
    atomic_store_release(&e->sequence, sequence);
}
/* }}} */
#endif

/* {{{ transcript_newest */
uint64_t transcript_newest(void)
{
#ifdef SOREN_DEBUG
    return atomic_load_acquire(&counter);
#else
    return 0;
#endif
}
/* }}} */

/* {{{ transcript_read */
int transcript_read(uint64_t from, struct transcript_event *out, int max, uint64_t *next)
{
#ifdef SOREN_DEBUG
    uint64_t newest = atomic_load_acquire(&counter);
    /* Anything older than one ring's length has been overwritten. */
    if (newest > TRANSCRIPT_ENTRIES && from <= newest - TRANSCRIPT_ENTRIES) {
        from = newest - TRANSCRIPT_ENTRIES + 1;
    }
    if (from == 0) from = 1;
    int n = 0;
    uint64_t s = from;
    for (; s <= newest && n < max; s++) {
        struct transcript_event *e = &ring[(s - 1) % TRANSCRIPT_ENTRIES];
        if (atomic_load_acquire(&e->sequence) != s) continue;
        out[n] = *e;
        __atomic_thread_fence(__ATOMIC_ACQUIRE);
        if (atomic_load_relaxed(&e->sequence) != s) continue;   /* torn while copying */
        n++;
    }
    *next = s;
    return n;
#else
    (void)from; (void)out; (void)max;
    *next = 0;
    return 0;
#endif
}
/* }}} */

/* {{{ transcript_format */
int transcript_format(const struct transcript_event *e, char *out, int size)
{
    static const char *const words[TRANSCRIPT_KIND_COUNT] = {
        [TRANSCRIPT_QUEUED] = "queued", [TRANSCRIPT_STARTED] = "started", [TRANSCRIPT_FINISHED] = "finished",
        [TRANSCRIPT_DELIVERED] = "delivered", [TRANSCRIPT_PLACED] = "placed", [TRANSCRIPT_WIRED] = "wired",
        [TRANSCRIPT_OUT_OF_SERVICE] = "out of service",
    };
    const char *word = e->kind < TRANSCRIPT_KIND_COUNT && words[e->kind] ? words[e->kind] : "?";
    return text_format(out, (size_t)size, "#%llu %llu.%06llu core %d %-14s station %d  %d %d %lld %s",
                       (unsigned long long)e->sequence, (unsigned long long)(e->when_ns / 1000000000ull),
                       (unsigned long long)(e->when_ns / 1000ull % 1000000ull), (int)e->core, word,
                       (int)e->station, (int)e->a, (int)e->b, (long long)e->c, e->note);
}
/* }}} */

/* {{{ transcript_live */
void transcript_live(int on)
{
#ifdef SOREN_DEBUG
    /* Switching the stream on starts it from now: the backlog is what the
     * crash dump is for, and replaying thousands of old events would bury
     * the new ones a person switched it on to watch. */
    if (on && !atomic_load_acquire(&live)) {
        spin_lock(&drain_lock);
        drained_to = atomic_load_acquire(&counter) + 1;
        spin_unlock(&drain_lock);
    }
    atomic_store_release(&live, on);
#else
    (void)on;
#endif
}
/* }}} */

/* {{{ transcript_drain_some */
void transcript_drain_some(void)
{
#ifdef SOREN_DEBUG
    if (!atomic_load_acquire(&live) || !spin_trylock(&drain_lock)) {
        return;
    }
    struct transcript_event batch[32];
    uint64_t next;
    int n = transcript_read(drained_to, batch, 32, &next);
    drained_to = next;
    spin_unlock(&drain_lock);
    for (int i = 0; i < n; i++) {
        char line[160];
        transcript_format(&batch[i], line, sizeof line);
        say_line("%s", line);
    }
#endif
}
/* }}} */

/* {{{ transcript_dump */
void transcript_dump(void)
{
#ifdef SOREN_DEBUG
    uint64_t from = 0;
    struct transcript_event batch[64];
    say_line("transcript: the last %d things the engine did, oldest first", TRANSCRIPT_ENTRIES);
    for (;;) {
        uint64_t next;
        int n = transcript_read(from, batch, 64, &next);
        for (int i = 0; i < n; i++) {
            char line[160];
            transcript_format(&batch[i], line, sizeof line);
            say_line("%s", line);
        }
        if (next > transcript_newest() || n == 0) break;
        from = next;
    }
#endif
}
/* }}} */
