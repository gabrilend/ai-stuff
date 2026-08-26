# 021-fixed-point

All the arithmetic the simulation is allowed to use. Every position, distance,
radius, and angle in the world passes through here, and none of it is floating
point.

**Why:** a recorded session has to replay to the same result on somebody else's
machine. A C compiler may reorder and fuse floating-point arithmetic in ways that
change the last bit, so two machines drift apart slowly and then all at once, an
hour into a replay, with nothing to point at. Integers give the compiler no such
freedom. The build checks the compiled objects for floating-point instructions
and fails if it finds any.

## The types

| Type | Underlying | Meaning |
| --- | --- | --- |
| `wcoord` | `int32_t` | A position or a distance, counted in 1/1024 of a metre. Range about ±2,100 km; precision about a millimetre. |
| `wangle` | `uint16_t` | An angle. A full turn is 65,536, so turning past a full circle wraps by overflowing, which is free and always correct. One step is about 0.0055°. |
| `struct wvec` | two `wcoord` | A direction or an offset. Used in transit; never stored in the world. |

Constants: `WC_SHIFT` (10) and `WC_ONE` (1024) for the coordinate scale;
`WA_TURN`, `WA_HALF`, `WA_QUARTER`, `WA_EIGHTH` for the angle space.

The simulation counts **metres**. The view converts to whole feet on its way to
the screen and never converts back — two clients rounding differently would
disagree about where a body stood.

## The functions

| Function | In | Out | What it does |
| --- | --- | --- | --- |
| `fx_mul` | two `wcoord` | `wcoord` | Multiplies. Widens to 64 bits first, because two values of a few metres overflow 32 bits once multiplied. Rounds symmetrically about zero. |
| `fx_div` | two `wcoord` | `wcoord` | Divides. Rounds half away from zero. Dividing by zero is a caller error and is not checked — the validator establishes it cannot happen. |
| `fx_dist2` | four `wcoord` | `int64_t` | Squared distance, in squared units, not shifted back down. What almost every caller actually wants. |
| `fx_dist` | four `wcoord` | `wcoord` | Distance. Prefer `fx_dist2` where a comparison will do. |
| `fx_sqrt` | `int64_t` | `wcoord` | Integer square root, by digit-by-digit binary restoration — a fixed number of steps, so the same input takes the same path on every machine. |
| `fx_sin`, `fx_cos` | `wangle` | `wcoord` | Read from a table generated at build time. `WC_ONE` is 1.0. No call into `libm`, which returns doubles. |
| `fx_angle` | two `wcoord` | `wangle` | The direction of a vector. The zero vector returns 0, which is a defined answer to an undefined question — callers who care must check the vector themselves. |
| `fx_from_angle` | `wangle`, `wcoord` | `struct wvec` | A vector of the given length in the given direction. Every movement step goes through this, so it reads the table at full precision rather than through `fx_sin`. |
| `fx_angle_diff` | two `wangle` | `int32_t` | The short way round, in [-32768, 32767]. Positive means counter-clockwise. Exactly half a turn resolves negative. |
| `fx_angle_in_arc` | angle, centre, arc | `int` | Whether an angle falls inside a wedge. An arc of 0 means nothing and 65535 means everything; those two are one comparison apart and getting them backwards is silent and total, which is why this is a function. |

## Rounding, which is the whole point of the file

Two operations round, and both round **symmetrically about zero**.

The naive versions do not. An arithmetic right shift rounds toward negative
infinity; C's integer division truncates toward zero. Either way, a body walking
left and a body walking right are treated differently, and a body oscillating
between them creeps steadily in one direction over a long session.

`022-test-fixed-point.c` pins this down. If somebody simplifies the rounding back
to a plain shift, that test says what broke.

## The tables

`021-sine-table-generator.c` runs at build time and emits `021-trig-table.h` —
a quarter turn of sine and an eighth turn of arctangent, as integers. It is the
only place in the project where a floating-point number exists, and its output is
frozen into the build before the server starts.

The tables are never committed. A fresh checkout runs `./build` and gets them.
