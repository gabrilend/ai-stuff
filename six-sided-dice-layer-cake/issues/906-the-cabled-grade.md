# 906 — The cabled grade

Produces `src/067-spout-cabled-grade.md`.

## Current behavior

Nothing. Two thousand and forty-eight pairs at thirty-two gigabits has been quoted
once.

## Intended behavior

**The detachable grade: a cable you can unplug, at a factor of two hundred and
fifty in width against the bonded one.**

### Why it exists

Because a machine you cannot take apart is a machine you cannot service, and
`207`'s whole position is that service means swapping a cube. A cube whose output
is bonded to something is a cube that cannot be swapped alone.

### What it is

Two thousand and forty-eight differential pairs on `801`'s perimeter zone at two
hundred and fifty micron pitch, through the via islands, to a connector, to
twinax. Thirty-two gigabits a pair gives sixty-five terabits a second — about
eight point two terabytes.

Eight terabytes a second is a rounding error next to two thousand one hundred, and
it is still thirty times a current network interface. The blueprint should give
both comparisons, because the first one makes it look like a failure and the
second makes it look like a triumph, and it is neither.

### Everything `903` omitted comes back

`903`'s driver is an inverter, because its channel is ten microns of copper. This
channel is a metre of twinax, and it needs the whole apparatus: termination,
equalisation at both ends, clock recovery per lane or per group, a training
sequence, and per-lane calibration state.

**So this is a completely different circuit**, not a variant, and the blueprint
must say so rather than describing it as the same thing at a different pitch. The
right move is to adopt an existing serial standard rather than specify one; there
is nothing about this link that is unusual, and an existing standard brings
connectors, cables, retimers and test equipment that already exist.

### The pane does not survive

A pane is two mebibytes arriving at once. Over two thousand and forty-eight serial
lanes it arrives over about two hundred and fifty-six nanoseconds, in lane order,
and has to be reassembled. That is fine — `909`'s translation unit is buffering
anyway — but it means the **cube-side interface is not the same** as the bonded
grade's, which contradicts `909`'s requirement that it be identical across
variants.

**This is a real conflict between two tickets** and this blueprint is where it is
resolved. The likely resolution: the cube always emits a pane, and the
serialisation happens in a fixed function block on the face, so that what leaves
the *cube* differs while what leaves the *core* does not. The blueprint must
choose and `909` must be updated.

## Symbols this must publish

Pair count, rate per pair, aggregate. Connector type and mating cycles. Channel
reach and loss budget. Equalisation and clock recovery requirements. Training
sequence duration. Serialisation latency for a whole pane. Comparison ratios
against `905` and against a network interface. Power.

## Constraints this must assert

- Pair count fits `801`'s perimeter zone and `202`'s via islands.
- Aggregate rate times a whole-core transfer time equals the core size — the
  honest statement of how long this grade takes to do what `905` does in
  thirty-three microseconds.
- Power is within `301`'s allocation.
- Reach exceeds the stated cable length with the loss budget met.
- The cube-side interface question is resolved consistently with `909`, checked
  across the two blueprints.

## Suggested implementation steps

1. Adopt an existing serial standard and say which.
2. State plainly that this is a different circuit from `903`, not a variant.
3. Work the serialisation latency and confront the `909` conflict.
4. Give both comparison ratios.

## Blocks

`909`, `1302`.

## Blocked by

`202`, `801`, `901`, `909`.

## Related documents

`007`. `207` for why detachability is worth two orders of magnitude.
