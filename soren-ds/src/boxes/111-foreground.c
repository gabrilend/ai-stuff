/*
 * 111-foreground.c — an event when a screen's foreground changes
 * (issue 604).
 *
 * General description: a box cannot remember the foreground it saw last,
 * so the last one rides a loop, as the input frame's history does (501,
 * 502). An app that wants to hear about changes places, in its own map:
 * `foreground_start`, which puts the screen and a first "seen" on the
 * loop; `foreground_track`, which on every tick it is given reads the
 * screen's foreground and sends round what it saw before and what it
 * sees now; and `foreground_changed`, placed as a comparator against an
 * event with every field zero, so only a tick where the foreground
 * changed leaves by "above" (exit 2), naming the screen, the app before
 * and the app after.
 */
#include <stdint.h>
#include "../system/104-surfaces.h"
#include "../system/110-foreground.h"

/* What a tracker saw: the screen, and the foreground at the tick before
 * and at this one. */
struct foreground_seen {
    int64_t screen;
    int64_t before;
    int64_t now;
};

/* One change, or nothing (every field zero). */
struct foreground_change {
    int64_t changed;              /* 1 for a change, 0 for nothing */
    int64_t screen;
    int64_t from;
    int64_t to;
};

/* {{{ foreground_change__compare */
/* A change is above nothing; the other fields only say which change. */
int foreground_change__compare(struct foreground_change a, struct foreground_change b)
{
    return a.changed < b.changed ? -1 : a.changed > b.changed ? 1 : 0;
}
/* }}} */

/* {{{ foreground_start */
/* The first value on the loop, as written in the map: which screen, and
 * the foreground to count as already seen (-2, none, makes the first tick
 * report whatever is the foreground then). */
struct foreground_seen foreground_start(struct foreground_seen first)
{
    first.now = first.before;
    return first;
}
/* }}} */

/* {{{ foreground_track */
struct foreground_seen foreground_track(int64_t tick, struct foreground_seen last)
{
    (void)tick;
    struct foreground_seen seen = { last.screen, last.now, screen_get_foreground((int)last.screen) };
    return seen;
}
/* }}} */

/* {{{ foreground_changed */
struct foreground_change foreground_changed(struct foreground_seen seen)
{
    struct foreground_change c = { 0, 0, 0, 0 };
    if (seen.before != seen.now) {
        c.changed = 1;
        c.screen = seen.screen;
        c.from = seen.before;
        c.to = seen.now;
    }
    return c;
}
/* }}} */
