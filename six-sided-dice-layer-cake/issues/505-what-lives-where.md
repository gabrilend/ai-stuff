# 505 — What lives where

Produces `src/038-core-address-map.md`.

## Current behavior

Nothing. Three regions with special meaning have been named in passing — staging
buffers, the pane window, the request region — and none has an address.

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
