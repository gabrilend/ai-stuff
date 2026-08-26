# 505 — What lives where

Produces `src/038-core-address-map.md`.

## Current behavior

**Done.** `src/038-core-address-map.md` exists with nine regions, each with a
size, an alignment and an owner, including the three that are not just storage:
the staging buffers, the pane window, and the request region — which is the
machine's only compatibility surface and is marked as such.

Seven constraints. One of them caught the interleave being **narrower than a
single cycle's read from one tier**, which would have meant every transfer
straddling two banks — the exact opposite of what interleaving is for.

**The interleaving is a stride and not an analysis**, and it is the piece of this
phase most likely to cost real bandwidth silently. `034` estimated bank
collisions assuming six independent address streams; they are six streams walking
six contiguous regions in step, and whether that helps or hurts depends entirely
on where those regions begin relative to the stride.

**The training regions are sized at zero when not training and the map has no
notion of a mode.** And nothing says what happens on an out-of-range address:
there is no protection here and no fault for it, so a face computing a wrong
address reads somebody else's region and produces plausible nonsense.

## Intended behavior

**The core's address space, region by region, with a size, an alignment, an owner
and an access rule for each.**

### The regions

| region | size | written by | read by |
|---|---|---|---|
| weight residency | ~35 GB | the storage lines, at load | all six faces |
| key and value cache | grows with context | the owning face | the owning face |
| sieve staging buffers | six, one per stage | stage *n* | stage *n+1* |
| the request region | small | the host link | face 0 and face 5 |
| the pane window | 2 MiB, aliased | nothing | the spout |
| scrub and repair state | small | `507` | `507` |
| control and status | small | anything | anything |

### The three that are not just storage

**The staging buffers** are the surface between pipeline stages. Six of them, each
holding a microbatch of activation vectors — sixteen kibibytes per token per
sequence, so a few hundred kibibytes at the batch sizes `1105` cares about. Their
size sets how far ahead a face may run, and `704` decides that, so this blueprint
takes the number rather than choosing it.

**The pane window** is not memory. It is an aliasing register that says which two
mebibytes of the core the spout currently sees. Moving it is one store. The
blueprint must specify the alignment — two mebibytes, naturally aligned, so the
spout's tiling in `902` maps to banks without a shift — and what happens if a
misaligned value is written, which should be a refusal rather than a rounding.

**The request region** is where a host puts a token identifier and takes one back.
It is the only part of the core with a defined layout that something outside the
cube writes, so it is the only part with a compatibility obligation, and the
blueprint should mark it as such.

### Interleaving is the real content

The weight region must be laid out so that a face reading its own layers
sequentially touches banks in a pattern that does not collide with the other five
faces doing the same thing in their own regions. That is an interleaving choice,
and it interacts with `504`'s arbitration and `703`'s transfer size.

**Get this wrong and the machine loses bandwidth to bank conflicts** while every
individual blueprint still checks. It is the sort of failure that only appears in
`1106`'s end-to-end model, which is why that model has to exist.

## Symbols this must publish

Base address and size per region. Alignment per region. Interleave granularity and
the bank-mapping function. Staging buffer size and count. Pane window size and
alignment. Total mapped size against `501`'s usable capacity.

## Constraints this must assert

- Regions do not overlap and sum to no more than usable capacity.
- The pane window's size and alignment match `902`'s tiling.
- Staging buffer size times count is at least what `704`'s look-ahead needs.
- Interleave granularity is at least `703`'s transfer size, so a single transfer
  is not split across banks.
- Weight region size is at least the reference model's from `1104`.

## Suggested implementation steps

1. Lay out the regions with sizes derived from their owners' blueprints.
2. Choose the interleaving from the six-stream access pattern and show the
   collision rate.
3. Fix the pane alignment against `902` and specify refusal on misalignment.
4. Mark the request region as the compatibility surface.
5. Sum and check against capacity.

## Blocks

`506`, `703`, `704`, `902`, `1104`.

## Blocked by

`501`, `504`.

## Related documents

`003` for what moves through the staging buffers. `007` for the pane.
