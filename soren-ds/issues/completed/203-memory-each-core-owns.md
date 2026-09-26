# 203 — Memory each core owns

## Current behavior

**Built and tested on the twin.** `src/engine/028-page-stripes.c` keeps
one bit per 4 KB page over the platform's pool, cut into stripes of 512
pages — one 64-byte cache line of bitmap each — and each stripe has one
owner: a core, or the "outside" owner that stands for callers that are
not cores (boot code; the twin's test thread). Each owner starts with a
quarter of the pool dealt out in interleaved stripes; the rest stays
unowned and is claimed one stripe at a time, with one compare-and-swap,
by whoever runs dry. A page freed by a non-owner goes onto the owner's
returns list and is cleared by the owner on its next allocation.

One departure from the text below, recorded where it happened: every
bitmap write is an atomic word operation (uncontended — only the owner
touches its line), because parking (213) must take back a page in
another core's stripe without asking. "No atomic at all" became "no
contended atomic".

Test `twin/tests/048-test-memory-each-core-owns.c`: four cores, 200,000
rounds each of allocate / free / hand-to-a-neighbour, every page stamped
with its holder — no stamp ever wrong, every page back at the end. The
cost of an allocate-and-free pair with one core busy and with four is
recorded (see the metrics pages); the two are the same, which is the
point of striping.

## Intended behavior

**Each core owns its own stripes of the bitmap and never touches
another core's bytes, so the ordinary allocation needs no atomic at
all.**

A lock around the walk would be correct and would also mean four cores
taking turns at the one thing all four do constantly. Splitting the
bitmap means there is nothing to take turns at.

```
  the pool's bitmap, one bit per page, striped by owner:

  ├─0─┼─1─┼─2─┼─3─┼─0─┼─1─┼─2─┼─3─┼─0─┼─1─┼─2─┼─3─┤ ...
    ▲                   ▲
    │                   └─ core 0's next stripe
    └─ core 0's first stripe

  core 0 scans only its own stripes.  no lock, no atomic,
  no other core's bytes ever read or written.
```

**Striped rather than quartered, and the stripe width is the whole
design.** Giving core 0 the bottom quarter of memory and core 1 the
next quarter would also avoid the race, but it puts each core's pages
in one distant lump. Interleaving keeps every core's memory spread
through the pool.

The width cannot be arbitrary, though, and the number comes from the
hardware:

| quantity | value | reasoning |
|---|---|---|
| one bitmap bit | 1 page | 4 KB of memory |
| one bitmap byte | 8 pages | 32 KB of memory |
| one cache line | 64 bytes of bitmap | 512 pages, **2 MB of memory** |
| **minimum stripe** | **one cache line** | below this, two cores' bits share a line |

**Why a shared line costs even when nothing races.** The caches move
memory in 64-byte lines, not bytes. If core 0's bits and core 1's bits
sit in the same line, then every time core 0 sets one of its own bits,
the hardware must take that line away from core 1 — not because
anything is racing, but because the two cores cannot both hold a
writable copy of one line. Core 1's next allocation then has to fetch
it back. The bits are unrelated; the line is not. This is *false
sharing*, and no lock removes it, because there is no lock involved.
Only the stripe width removes it.

**Borrowing is the one operation that arbitrates.** A core that
exhausts its own stripes takes another stripe from a neighbour. That is
rare, it moves ownership of a whole stripe rather than a page, and it
is the only place in the allocator where two cores talk. It can afford
to be careful and slow.

| operation | how often | cost |
|---|---|---|
| allocate a page from your own stripe | constantly | a scan of your own bytes; nothing shared |
| free a page in your own stripe | constantly | clear one bit; nothing shared |
| free a page in someone else's stripe | occasionally | see below |
| borrow a stripe from a neighbour | rarely | one arbitrated hand-over |

**A page freed by a core that did not allocate it** is the case that
looks like it needs a lock and does not. The freeing core does not
clear the bit itself; it hands the page back to its owner by leaving it
on that owner's returns list, which the owner drains on its next
allocation. One core writes, one core reads, and the bit is only ever
cleared by the core that owns the byte it lives in.

## Suggested implementation steps

1. Extend 108's allocator with a stripe table: which core owns which
   stripes, computed once at initialization from the core count and the
   pool size.
2. Per-core allocation state — where its scan last stopped, which
   stripes it holds — kept in memory sized and placed so two cores'
   state never shares a cache line either. The same rule applies one
   level up.
3. Allocation: scan your own stripes from your own bookmark, wrapping
   once, and stop.
4. The returns list per core, and draining it at the top of an
   allocation so a returned page is reused before a fresh one is
   scanned for.
5. Borrowing, as the one arbitrated operation, when a core's own scan
   comes back empty.
6. A test with all four cores allocating and freeing continuously,
   asserting no page is ever handed to two owners and the totals
   balance at the end.
7. Measure allocation cost per core with one core busy and with four,
   and confirm the second number is not worse — if it is, the stripe
   width is wrong and the measurement will say so.

## Open questions

- *What happens when every core is out and no neighbour has a stripe to
  give?* This is genuine exhaustion, and it should say so and stop
  rather than return nothing and let the caller invent a policy.
- *Are stripes fixed at boot or handed out as needed?* Fixed is
  simpler and wastes the tail; on-demand means the stripe table itself
  becomes shared state. Leaning fixed, since the pool is 3 GB and the
  tail is rounding error.
- *What about an allocation larger than a stripe?* The framebuffer in
  111a wants a large contiguous run. That is a different operation with
  a different owner and probably belongs outside the striped path
  entirely — a one-time reservation taken before the stripes are handed
  out at all.
- *Does the borrow need a lock, or is it one compare-and-swap on a
  stripe's owner field?* The second, if 201's open question about
  exclusives resolves the way it should.

### Proposed answers (UNVERIFIED)

1. *Genuine exhaustion?* Implemented as proposed: `page_alloc` says so on
   the developer's line and answers nothing; the caller records
   "no memory" in the station's error slot (214).
2. *Fixed or on demand?* Both: a fixed quarter dealt out at startup,
   the rest claimed a stripe at a time. On-demand stripes cost one
   compare-and-swap on a byte nobody writes afterwards.
3. *Larger than a stripe?* Runs up to one stripe (2 MB) are served from
   inside one stripe (`pages_alloc_run`); anything larger — the device
   framebuffers — stays with phase 1's allocator, taken before the
   engine's pool is carved.
4. *Borrow by compare-and-swap?* Yes — on the unowned pool, which is the
   only borrowing there is.

## Blocked by

201 (false sharing only becomes a cost once caches exist; the atomics
only become defined then too), 202 (there must be cores to own
stripes), 108 (the allocator this extends).

## Blocks

210 (task memory sits directly on this), and every later allocation.

## Related

- [108 — Flat page allocator](completed/108-flat-page-allocator.md),
  whose deferred concurrency control this is
- [210 — The task](210-the-task.md), the allocator's hottest caller
- [007 — Memory model](../docs/007-memory-model.md)
