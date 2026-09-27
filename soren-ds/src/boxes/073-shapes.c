/*
 * 073-shapes.c — value types that show what "compared by width" means
 * (issue 303).
 *
 * General description: a wire is legal when both ends count the same
 * bytes, and nothing else is consulted. So a `point` and a `pair` — the
 * same layout under different names — wire together and carry each other
 * byte for byte, with no adapter box; and a `point` and a `flipped` — the
 * same width with the fields in the other order — also wire together, and
 * arrive scrambled. That second pair exists on purpose, so that whoever
 * finds it later finds a decision rather than an oversight.
 */
#include <stdint.h>

struct point {
    int32_t x;
    int32_t y;
};

struct pair {
    int32_t first;
    int32_t second;
};

struct flipped {
    int32_t y;
    int32_t x;
};

/* {{{ make_point */
struct point make_point(int64_t seed)
{
    struct point p;
    p.x = (int32_t)seed;
    p.y = (int32_t)(seed * 10);
    return p;
}
/* }}} */

/* {{{ pair_sum */
/* Takes a pair — fed straight from a box that returns a point. */
int64_t pair_sum(struct pair p)
{
    return (int64_t)p.first * 1000 + p.second;
}
/* }}} */

/* {{{ flipped_x */
/* Takes a flipped — fed from a point, its x is the point's y. */
int64_t flipped_x(struct flipped f)
{
    return f.x;
}
/* }}} */
