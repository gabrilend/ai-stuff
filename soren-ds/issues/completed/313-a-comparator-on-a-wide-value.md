# 313 — A comparator on a value wider than 64 bytes

## Current behavior

A comparator copies its threshold out of its static port into a 64-byte
buffer on the stack before comparing (`exit_comparator`,
`src/engine/036-delivery.c`). When the box's return type is wider than
that, the comparator answers "discard" for every value: nothing leaves
by any exit, the station records no error, and the loader accepted the
map without a word. The weighted kind has the same shape with its 64
weights, but there the limit is a count of exits, which the loader
already checks.

Found while building the button events (502, PR #218): `struct
button_event` first carried eighteen 64-bit durations (168 bytes), and
every event vanished silently. The event was made small instead (16-bit
milliseconds, 56 bytes), and that PR's test asserts it stays within 64.

## Intended behavior

A comparator either works on any value a port can carry, or the loader
refuses to place one whose return type is wider than its threshold can
be, naming the type and the limit — the same "everything wrong with a
map said at once" rule as 307. Never a station that quietly eats its
input.

## Suggested implementation steps

1. Decide between the two (see the open question).
2. Either compare against the static port's bytes without copying them
   (the static value is written under a sequence count, so this needs a
   retry around the compare, not just the copy), or check the width in
   the loader (068) beside the other width checks and refuse.
3. A test placing a comparator on a 168-byte value, in 075.

## Open questions

- *Lift the limit, or refuse past it?*

### Proposed answers (UNVERIFIED)

1. *Refuse in the loader* — decided for now. It is a few lines beside the
   checks that already exist, and no box so far wants a wide comparator.
   **Lifting the limit stays open for Ritz**: the static value is written
   under a sequence count, so comparing in place needs the compare inside
   the retry loop, or a larger buffer (a 64 KiB value cannot go on a
   core's stack).

## What happened

The loader refuses, as answered. `ENGINE_THRESHOLD_BYTES` (64) in
`031-engine.h` names the limit, and the comparator's buffer in
`036-delivery.c` is sized by it, so the two cannot drift apart. A
comparator whose box returns more is a problem like any other in 307's
list: "`split` is a comparator, but `widen` returns `struct wide`, which
is 72 bytes; a comparator can compare values of at most 64 bytes (issue
313)", on the line that places it, and nothing is placed.

Only the loader checks. A station placed by hand through `engine_place`
(tests, and 411's replacement path) is not refused; the engine still
discards rather than read past its buffer, as before.

Test `twin/tests/101` (10 checks): a hand-made 72-byte box with an
ordering is refused as a comparator with that line and places nothing,
loads and runs as a plain station, and a comparator on text — exactly 64
bytes — still loads and still splits. With the check removed, three of
its checks fail.

## Related

- `issues/completed/308-the-kinds-that-pick-an-exit.md` — the kinds.
- `issues/completed/307-everything-wrong-with-a-map-said-at-once.md`.
- Issue 502 (PR #218) — where it was found.

## Blocked by

Nothing.

## Blocks

Nothing yet; any comparator on a wide value type.
