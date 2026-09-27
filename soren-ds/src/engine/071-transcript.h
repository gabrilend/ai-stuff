/*
 * 071-transcript.h — recent history, in debug builds (issue 311).
 *
 * General description: phase 2's error slots answer "what failed, and how
 * often"; they cannot answer "what was going on just before". The
 * transcript is a fixed ring of the last few thousand things the engine
 * did — a task queued, started, finished; a value delivered; a station
 * placed, wired, or taken out of service — overwritten oldest first,
 * never growing, never allocating, written without a lock. Two readers:
 * a live stream a parked core drains to the developer's line when asked
 * to, and a crash dump the halt path writes out before stopping.
 *
 * In an ordinary build every call below compiles to nothing, and the
 * ring itself does not exist.
 */
#ifndef SOREN_TRANSCRIPT_H
#define SOREN_TRANSCRIPT_H

#include <stdint.h>

#define TRANSCRIPT_ENTRIES 4096

enum transcript_kind {
    TRANSCRIPT_QUEUED = 1,       /* a task was built and pushed: station, bytes in */
    TRANSCRIPT_STARTED,          /* a core began a task: station, core */
    TRANSCRIPT_FINISHED,         /* a core finished it: station, nanoseconds, bytes out */
    TRANSCRIPT_DELIVERED,        /* a value landed: from station, to station, port */
    TRANSCRIPT_PLACED,           /* a station came into existence */
    TRANSCRIPT_WIRED,            /* an exit was given destinations: station, exit, count */
    TRANSCRIPT_OUT_OF_SERVICE,   /* a station took itself out: station, error kind */
    TRANSCRIPT_KIND_COUNT
};

struct transcript_event {
    uint64_t sequence;           /* 1, 2, 3 ... ; 0 = never written. A reader checks it did not change under it */
    uint64_t when_ns;
    uint16_t kind;
    int16_t  core;
    int32_t  station;
    int32_t  a;
    int32_t  b;
    int64_t  c;
    char     note[24];           /* text is truncated in place; never a pointer */
};

#ifdef SOREN_DEBUG
void transcript_record(int kind, int32_t station, int32_t a, int32_t b, int64_t c, const char *note);
#else
#define transcript_record(kind, station, a, b, c, note) ((void)0)
#endif

/* Copy events with sequence numbers from `from` onward, oldest first, up
 * to `max`; answers how many, and the next sequence to ask for. Events
 * already overwritten are skipped (the ring kept the newest). */
int  transcript_read(uint64_t from, struct transcript_event *out, int max, uint64_t *next);
uint64_t transcript_newest(void);

/* One event as a line of text. */
int  transcript_format(const struct transcript_event *e, char *out, int size);

/* The live stream: when switched on, a core about to park writes out up to
 * a few dozen new events first — so a busy device streams nothing until it
 * goes quiet, and the stream never competes with work (issue 311's second
 * open question, answered that way). */
void transcript_live(int on);
void transcript_drain_some(void);

/* The crash dump: every event still in the ring, oldest first. */
void transcript_dump(void);

#endif
