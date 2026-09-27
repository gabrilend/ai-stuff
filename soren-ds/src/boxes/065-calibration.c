/*
 * 065-calibration.c — the seventh routing kind, as two boxes and an arrow
 * (issue 308).
 *
 * General description: the old design had a kind that kept a ring of
 * recent values on its station, worked out their range, normalised the
 * newest against it and bent it through an S-curve. That is not a way of
 * choosing an exit; it is a box that remembers, and a box cannot remember.
 * So it is two boxes, and the range travels on a wire:
 *
 *   value ──┬──→ recalibrate ──→ new range ──┐
 *           │         ▲                      │
 *           │         └──── range, going round (a loop: the only state)
 *           └──→ shape ←─────────────────────┘ ──→ shaped value
 *
 * One honest caveat, from the issue: a station takes whatever is at the
 * head of each port, so the range arriving at `shape` is not necessarily
 * the one computed from the value beside it. Fine for a slowly drifting
 * calibration; anything that must pair exactly must be one value on one
 * wire.
 *
 * No floating point: the S-curve is integer arithmetic on a 0..1000 scale.
 */
#include <stdint.h>

struct range {
    int64_t low;
    int64_t high;
};

/* {{{ recalibrate */
/* The range widened to include the value. */
struct range recalibrate(int64_t value, struct range seen)
{
    if (seen.low > seen.high) {                /* an empty range: start it here */
        seen.low = value;
        seen.high = value;
    }
    if (value < seen.low) seen.low = value;
    if (value > seen.high) seen.high = value;
    return seen;
}
/* }}} */

/* {{{ shape */
/* The value placed within the range on a 0..1000 scale, then bent through
 * smoothstep (3x² − 2x³), so the middle is steep and the ends are gentle. */
int64_t shape(int64_t value, struct range seen)
{
    int64_t span = seen.high - seen.low;
    if (span <= 0) {
        return 500;
    }
    int64_t x = (value - seen.low) * 1000 / span;
    if (x < 0) x = 0;
    if (x > 1000) x = 1000;
    return (3 * x * x * 1000 - 2 * x * x * x) / 1000000;
}
/* }}} */
