/*
 * 021-fixed-point.c -- the integer arithmetic the whole simulation runs on.
 *
 * Interface and reasoning are in 021-fixed-point.h. What lives here is the care:
 * the rounding rule, the angle reflections, and the handful of places where the
 * obvious implementation is subtly asymmetric about zero.
 *
 * Nothing in this file may use a floating-point type. The build checks.
 */

#include "021-fixed-point.h"
#include "021-trig-table.h"

#define SIN_SHIFT 16

/* {{{ wcoord fx_mul */
wcoord fx_mul(wcoord a, wcoord b)
{
    /*
     * Widen before multiplying. Two values of a few metres each overflow 32 bits
     * once multiplied, so the intermediate is 64-bit and comes back down after
     * the shift.
     */
    int64_t wide = (int64_t)a * (int64_t)b;

    /*
     * An arithmetic right shift on a negative number rounds toward negative
     * infinity, which is asymmetric -- it biases every leftward movement by a
     * fraction that the rightward movement does not get. Over a long session
     * that is a slow drift, so the sign is taken out, the shift is done on a
     * positive number, and the sign is put back.
     */
    if (wide < 0) {
        return -(wcoord)(((-wide) + (WC_ONE / 2)) >> WC_SHIFT);
    }

    return (wcoord)((wide + (WC_ONE / 2)) >> WC_SHIFT);
}
/* }}} */

/* {{{ wcoord fx_div */
wcoord fx_div(wcoord a, wcoord b)
{
    int64_t numerator = ((int64_t)a) << WC_SHIFT;
    int64_t half;
    int     negative = 0;

    /*
     * Division by zero is a caller error, not a case to be absorbed. The
     * validator establishes that the divisors reaching this function are
     * non-zero; if one ever is, the crash is the correct outcome and is more
     * useful than a substituted value that lets a wrong world keep running.
     */

    /*
     * Round half away from zero, symmetrically. C's own integer division
     * truncates toward zero, which sounds symmetric and is not: it shortens both
     * directions rather than rounding either, so a body walking left and a body
     * walking right both fall short, and a body oscillating between them creeps.
     */
    if (numerator < 0) {
        numerator = -numerator;
        negative = !negative;
    }

    if (b < 0) {
        b = -b;
        negative = !negative;
    }

    half = (int64_t)b / 2;

    if (negative) {
        return -(wcoord)((numerator + half) / (int64_t)b);
    }

    return (wcoord)((numerator + half) / (int64_t)b);
}
/* }}} */

/* {{{ int64_t fx_dist2 */
int64_t fx_dist2(wcoord ax, wcoord ay, wcoord bx, wcoord by)
{
    int64_t dx = (int64_t)ax - (int64_t)bx;
    int64_t dy = (int64_t)ay - (int64_t)by;

    /*
     * No shift back down. This is a squared quantity in squared units, and
     * callers compare it against another squared quantity. Shifting here would
     * throw away precision for a number nobody reads directly.
     */
    return (dx * dx) + (dy * dy);
}
/* }}} */

/* {{{ wcoord fx_sqrt */
wcoord fx_sqrt(int64_t v)
{
    int64_t remainder = v;
    int64_t result    = 0;
    int64_t bit;

    /* A negative squared distance means a caller computed something impossible. */
    if (v <= 0) {
        return 0;
    }

    /*
     * Integer square root by digit-by-digit binary restoration. Chosen over
     * Newton's method because it terminates in a fixed number of steps with no
     * convergence test, which makes it trivially deterministic -- the same input
     * takes the same path every time on every machine.
     */
    bit = (int64_t)1 << 62;
    while (bit > remainder) {
        bit >>= 2;
    }

    while (bit != 0) {
        if (remainder >= result + bit) {
            remainder -= result + bit;
            result = (result >> 1) + bit;
        } else {
            result >>= 1;
        }
        bit >>= 2;
    }

    return (wcoord)result;
}
/* }}} */

/* {{{ wcoord fx_dist */
wcoord fx_dist(wcoord ax, wcoord ay, wcoord bx, wcoord by)
{
    return fx_sqrt(fx_dist2(ax, ay, bx, by));
}
/* }}} */

/* {{{ static int32_t sine_raw */
static int32_t sine_raw(wangle a)
{
    /*
     * The table holds one quarter turn. The rest of the circle is that quarter
     * reflected, and which reflection depends on which quadrant the angle is in.
     *
     * Quadrant 0 (0 to 90 deg)    -- read forward, positive.
     * Quadrant 1 (90 to 180 deg)  -- read backward, positive.
     * Quadrant 2 (180 to 270 deg) -- read forward, negative.
     * Quadrant 3 (270 to 360 deg) -- read backward, negative.
     */
    unsigned int quadrant = (unsigned int)a >> 14;
    unsigned int offset   = (unsigned int)a & (WA_QUARTER - 1);

    switch (quadrant) {
    case 0:
        return trig_sine_quarter[offset];
    case 1:
        return trig_sine_quarter[WA_QUARTER - offset];
    case 2:
        return -trig_sine_quarter[offset];
    default:
        return -trig_sine_quarter[WA_QUARTER - offset];
    }
}
/* }}} */

/* {{{ wcoord fx_sin */
wcoord fx_sin(wangle a)
{
    /*
     * The table is kept at 16 bits of fraction so that fx_from_angle keeps its
     * precision. Callers asking for a bare sine get it narrowed to the world's
     * own scale, which is all a position can hold anyway.
     */
    int32_t raw = sine_raw(a);

    if (raw < 0) {
        return -(wcoord)(((-(int64_t)raw) * WC_ONE) >> SIN_SHIFT);
    }

    return (wcoord)(((int64_t)raw * WC_ONE) >> SIN_SHIFT);
}
/* }}} */

/* {{{ wcoord fx_cos */
wcoord fx_cos(wangle a)
{
    /* Cosine is sine a quarter turn ahead. The addition wraps, which is correct. */
    return fx_sin((wangle)(a + WA_QUARTER));
}
/* }}} */

/* {{{ struct wvec fx_from_angle */
struct wvec fx_from_angle(wangle a, wcoord length)
{
    struct wvec out;

    /*
     * Read the table at full precision rather than going through fx_sin, because
     * this is the function every movement step uses and narrowing twice would
     * lose about a millimetre per step for no reason.
     */
    int64_t s = sine_raw((wangle)(a + WA_QUARTER));   /* cosine -> x */
    int64_t c = sine_raw(a);                          /* sine   -> y */

    out.x = (wcoord)((s * (int64_t)length) >> SIN_SHIFT);
    out.y = (wcoord)((c * (int64_t)length) >> SIN_SHIFT);

    return out;
}
/* }}} */

/* {{{ wangle fx_angle */
wangle fx_angle(wcoord x, wcoord y)
{
    int64_t ax = (x < 0) ? -(int64_t)x : (int64_t)x;
    int64_t ay = (y < 0) ? -(int64_t)y : (int64_t)y;
    int64_t smaller;
    int64_t larger;
    int64_t index;
    uint16_t base;

    /*
     * The zero vector has no direction. Returning zero is a defined answer to an
     * undefined question, and callers who care must check the vector themselves
     * rather than reading meaning into this.
     */
    if (ax == 0 && ay == 0) {
        return 0;
    }

    /*
     * The table covers one eighth of a turn, the slice where the smaller
     * component is on top of the ratio. Everything else is that slice reflected,
     * so the work is to find which of the eight octants this vector is in.
     */
    if (ay > ax) {
        smaller = ax;
        larger  = ay;
    } else {
        smaller = ay;
        larger  = ax;
    }

    index = (smaller * 1024 + (larger / 2)) / larger;
    if (index > 1024) {
        index = 1024;
    }

    base = trig_arctan[index];

    /*
     * Eight octants, counter-clockwise from the positive x axis. Each line is
     * the same angle measured from a different edge, which is why half of them
     * subtract: an octant read from its far edge runs backwards.
     */
    if (x >= 0 && y >= 0) {
        return (ax >= ay) ? (wangle)base : (wangle)(WA_QUARTER - base);
    }

    if (x < 0 && y >= 0) {
        return (ax >= ay) ? (wangle)(WA_HALF - base) : (wangle)(WA_QUARTER + base);
    }

    if (x < 0 && y < 0) {
        return (ax >= ay) ? (wangle)(WA_HALF + base)
                          : (wangle)(WA_HALF + WA_QUARTER - base);
    }

    return (ax >= ay) ? (wangle)(0 - base) : (wangle)(WA_HALF + WA_QUARTER + base);
}
/* }}} */

/* {{{ int32_t fx_angle_diff */
int32_t fx_angle_diff(wangle from, wangle to)
{
    /*
     * Subtract in the 16-bit space, where the wrap is automatic, then reinterpret
     * as signed. The result is the short way round, which is what every caller
     * that turns something toward something else actually wants.
     */
    uint16_t raw = (uint16_t)(to - from);

    if (raw >= WA_HALF) {
        return (int32_t)raw - WA_TURN;
    }

    return (int32_t)raw;
}
/* }}} */

/* {{{ int fx_angle_in_arc */
int fx_angle_in_arc(wangle a, wangle centre, wangle arc)
{
    int32_t difference;
    int32_t half;

    /*
     * Two ends of the same comparison, and getting them the wrong way round is
     * silent and total -- a body that sees everything or a body that sees
     * nothing, with no error either way. Both are written out explicitly rather
     * than left to fall out of the arithmetic.
     */
    if (arc == 0) {
        return 0;   /* Sees nothing. */
    }

    if (arc >= (WA_TURN - 1)) {
        return 1;   /* Sees everything; the two bounding edges have met. */
    }

    difference = fx_angle_diff(centre, a);
    half = (int32_t)arc / 2;

    if (difference < 0) {
        difference = -difference;
    }

    return (difference <= half) ? 1 : 0;
}
/* }}} */
