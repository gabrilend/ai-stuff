# 607 — The memory a face keeps to itself

Produces `src/047-face-cache-slice.md`.

## Current behavior

**Done.** `src/047-face-cache-slice.md` exists, built around the constraint that
sized the cube: the slice must hold the layer being computed and the layer being
fetched.

Seven constraints. The margin on the binding one is published as a number rather
than as a pass, because a constraint that holds by three per cent and one that
holds by a factor of two are different situations and a checker reports both the
same way.

The density difference against the core's tiers is argued rather than assumed —
a slice on a logic die carries its own sense amplifiers, its own correction, its
own three-port banking and shares routing with the engine beside it — and a
constraint asserts the inequality so that somebody unifying the two numbers fails
here rather than silently losing a quarter of the slice.

**`009` entry F2 is priced and not decided.** A third buffer would absorb
contention between faces at large batch and does not fit on this die; the larger
die has not been costed.

## Intended behavior

**The face-local static memory: its capacity, its banking, its ports, and the
constraint that sizes it.**

### The constraint, which is the whole ticket

    C_face_slice  >=  2 * C_layer_weights

The slice must hold the layer being computed **and** the layer being fetched behind
it. Without both, `805`'s prefetch cannot hide the core read and the machine runs
at the speed of an unoverlapped memory transfer.

For the reference model a layer is four hundred and thirty-seven megabytes at four
bits, so the requirement is eight hundred and seventy-four. Half of a
twenty-four millimetre die at the areal density achievable with logic on the same
die gives two hundred and thirty per die, nine hundred and twenty-two per face.

**Forty-eight megabytes of margin on a nine hundred megabyte number.** Five per
cent. This is the tightest constraint in the blueprint set and it is the one that
made the die twenty-four millimetres and the cube sixty.

The blueprint must present it that way, and must show what happens on either side:
a slightly larger model and the die grows; a slightly denser memory and it
shrinks.

### Why the density is lower than the core's

The core's tiers manage one and a half megabytes per square millimetre because
they are dedicated array with the periphery on a separate lamina. A face slice
shares its die with multipliers, a sequencer, a link and a power grid, so it
carries its own sense amplifiers and its own routing and gets about eight tenths.
Two different numbers for the same technology, and the blueprint must say why or
somebody will unify them and lose two hundred megabytes.

### The ports

Three clients with very different patterns:

- **The engine** reads at full rate, sequentially, from the resident layer. This is
  the design case and everything else must not disturb it.
- **The radial link** writes at full rate into the other buffer. Also sequential,
  also large.
- **The sequencer** makes small reads of its own control structures. Rare, small,
  and latency-sensitive, which is the awkward one.

Banking must let the first two run concurrently at full rate without conflict,
which is easy because they are in different buffers, and must not make the third
wait behind a long burst, which is not.

### The third layer question

`009` entry F2 asks whether a face should hold three layers rather than two. A
third buffer would let the core read run further ahead and smooth contention
between faces at large batch. It costs another four hundred and thirty-seven
megabytes, which does not fit. The blueprint should price the die growth it would
need and hand the trade to `1201`.

## Symbols this must publish

Areal density on a logic die. Capacity per die and per face. Buffer count and
size. Bank count and width. Per-port bandwidth. Conflict probability for the
sequencer's small reads. Read and write energy per bit. Leakage. Area and the
margin against the two-layer requirement.

## Constraints this must assert

- **Capacity is at least twice a layer's weights from `1104`.** The binding one.
- Engine read bandwidth is at least what `605` consumes at full utilisation.
- Link write bandwidth is at least what `806`'s prefetch requires.
- Slice read energy times the engine's consumption rate matches the slice term in
  `301`.
- Area matches `601`'s allocation.

## Suggested implementation steps

1. Derive the requirement from `1104` and the capacity from `601` and the density,
   and put the margin in the blueprint as a percentage so its tightness is visible.
2. Justify the density difference against the core's.
3. Design the banking for the three clients and bound the sequencer's wait.
4. Price the third buffer and hand it to `1201`.

## Blocks

`601`, `605`, `608`, `805`, `1104`.

## Blocked by

`502` for the density comparison, `601` for the area, `1104` for the layer size.

## Related documents

`004` for the reuse the slice exists to enable. `012` for the chain from a layer's
size to the cube's.
