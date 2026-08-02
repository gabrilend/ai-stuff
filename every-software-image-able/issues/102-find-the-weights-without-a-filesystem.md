# 102 — Find the weights without a filesystem

## Current behavior

Nothing locates the packed blob. On an ordinary computer this is a file open; here
there are no files, because a filesystem is software and none has been written.

## Intended behavior

The engine, running with nothing beneath it, finds the packed weights and knows
how much usable memory exists to work in — before any allocator exists, because
the allocator is something the grown machine writes later (`docs/003`).

## Suggested implementation steps

1. Decide where the blob sits in the image and how the engine finds it. The two
   candidates: a fixed offset agreed between the image builder and the engine, or
   a small table at a fixed offset that points at everything. The second costs one
   indirection and survives the layout changing; the first costs nothing and
   breaks silently when anything moves.
2. Read the memory map the firmware leaves behind. On the first target this is a
   list of address ranges each marked usable, reserved, firmware-owned or broken.
   Only the usable ranges may be touched.
3. Mark the ranges holding the engine and the weights as occupied, so that
   nothing later hands them out. This is the same rule the grown machine's
   allocator inherits — protect your own author before serving anyone else — and
   it is stated in `docs/003` step one for that reason.
4. Decide whether the weights are copied into memory or read in place. Copying
   costs the memory twice and buys speed; reading in place costs nothing and is
   slow if the medium is slow. The delivery medium is expected to be read-only
   (`docs/003`), which makes reading in place safe but not necessarily fast.
5. Produce a memory report: total usable, occupied by engine, occupied by
   weights, free for working memory. It is the first thing the machine can say
   about itself and it should be printable before anything else works.

## Blocks

`103`, `104`, `105`.

## Blocked by

`101` — the layout has to exist before it can be found.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the memory map, and the rule about
protecting the model's own weights.
