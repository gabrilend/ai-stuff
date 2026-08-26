/*
 * 021-fixed-point.h -- all the arithmetic this world is allowed to use.
 *
 * Every position, distance, radius and angle in the simulation is an integer.
 * There is no floating point anywhere below this line, and that is the single
 * decision this file exists to enforce.
 *
 * The reason is reproducibility. A recorded session has to replay to the same
 * result on somebody else's machine, and a C compiler is permitted to reorder
 * and fuse floating-point arithmetic in ways that change the last bit -- so two
 * machines, or two optimisation levels, drift apart slowly and then all at once,
 * an hour into a replay, with nothing to point at. Integer arithmetic gives the
 * compiler no such freedom.
 *
 * See docs/005-a-thing-in-the-world.md and issues/101-the-arithmetic-is-integers.md.
 */

#ifndef VTT_FIXED_POINT_H
#define VTT_FIXED_POINT_H

#include <stdint.h>

/*
 * The simulation counts metres. One world unit is 1/1024 of a metre, which puts
 * the range at about +/- 2,100 kilometres and the precision at about a
 * millimetre. Nothing in the server has ever heard of a foot -- the view
 * converts to whole feet on its way to the screen, and never converts back,
 * because two clients rounding differently would disagree about where a body
 * stood.
 *
 * If this shift ever changes, every world file written under the old one becomes
 * unreadable, which is why the scale is written into the file header and checked
 * on load rather than assumed.
 */
#define WC_SHIFT 10
#define WC_ONE   (1 << WC_SHIFT)

/* A world coordinate, or any distance, in 1/1024 metre. */
typedef int32_t wcoord;

/*
 * An angle. A full turn is 65536, so turning past a full circle wraps by
 * overflowing, which is free and always correct. One step is about 0.0055
 * degrees, which is far finer than anything at a tabletop can perceive.
 */
typedef uint16_t wangle;

#define WA_TURN     65536
#define WA_HALF     32768
#define WA_QUARTER  16384
#define WA_EIGHTH    8192

/* A vector. Used for directions and offsets; never stored in the world. */
struct wvec {
    wcoord x;
    wcoord y;
};

/*
 * Multiply two fixed-point values. The intermediate needs 64 bits before it is
 * shifted back down -- a caller doing this by hand overflows at about two metres.
 */
wcoord fx_mul(wcoord a, wcoord b);

/*
 * Divide two fixed-point values. Rounds half away from zero, which is symmetric
 * about the origin. C's own integer division truncates toward zero, so a body
 * drifting left and a body drifting right would round differently and slowly
 * diverge; this function exists so that never happens by accident.
 * Dividing by zero is a caller error and is not checked here -- the validator
 * establishes that it cannot happen.
 */
wcoord fx_div(wcoord a, wcoord b);

/*
 * Squared distance, in fixed point. This is what almost every caller actually
 * wants, and it is offered first so that nobody reaches for a square root out of
 * habit. Returns int64_t because a squared distance across a large map does not
 * fit in 32 bits.
 */
int64_t fx_dist2(wcoord ax, wcoord ay, wcoord bx, wcoord by);

/* Integer square root of a squared distance, for the cases that need a length. */
wcoord fx_sqrt(int64_t v);

/* Distance between two points. Prefer fx_dist2 where a comparison will do. */
wcoord fx_dist(wcoord ax, wcoord ay, wcoord bx, wcoord by);

/*
 * Sine and cosine of an angle, returned in fixed point where WC_ONE is 1.0.
 * Read from a table generated at build time; there is no call into libm, because
 * libm returns doubles.
 */
wcoord fx_sin(wangle a);
wcoord fx_cos(wangle a);

/*
 * The angle of the vector (x, y), measured the way `facing` is measured. The
 * inverse of fx_sin and fx_cos, for pointing a body at a thing.
 * The zero vector has no angle; it returns 0, and callers who care must check
 * for it themselves rather than relying on that.
 */
wangle fx_angle(wcoord x, wcoord y);

/*
 * A unit vector in the direction of an angle, scaled to `length`. Every movement
 * step goes through this.
 */
struct wvec fx_from_angle(wangle a, wcoord length);

/*
 * The shortest signed difference between two angles, in the range
 * [-32768, 32767]. Positive means `to` is counter-clockwise of `from`.
 * Used wherever something turns toward something else.
 */
int32_t fx_angle_diff(wangle from, wangle to);

/*
 * Whether `a` lies inside the wedge centred on `centre` and `arc` wide.
 * An arc of 65535 means everything; an arc of 0 means nothing. Those two cases
 * are one comparison apart and getting them backwards is silent and total, which
 * is why this is a function rather than something callers write inline.
 */
int fx_angle_in_arc(wangle a, wangle centre, wangle arc);

#endif
