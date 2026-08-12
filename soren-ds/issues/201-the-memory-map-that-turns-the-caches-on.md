# 201 — The memory map that turns the caches on

## Current behavior

**No translation table is loaded, and on this chip that is not a
neutral state.**

Phase 1 left the memory management unit switched off, on the reasoning
that translation is a phase 9 concern. Translation is. But the same
hardware block carries a second job, and switching it off switches off
both.

With no table loaded, the cores treat **every** data access as Device
memory. That is not "the same as before, just without translation" —
it is a different kind of memory with different rules:

| with no table loaded | consequence |
|---|---|
| nothing is cached, ever | the clock probe measured ~35x slow and correctly named this, not the clock, as the lever |
| unaligned accesses fault | a struct field at an odd offset is an exception, not a slow read |
| accesses are not reordered or merged | correct for a hardware register, wasteful for RAM |
| **the exclusive instructions are undefined** | the whole engine above this rests on them |

That last row is the one that stops phase 2 before it starts. A
compare-and-swap on these cores is built from a load-exclusive followed
by a store-exclusive, and the architecture only defines that pair on
Normal memory. On Device memory the behaviour is unspecified: it may
fault, or — far worse — it may succeed on each core independently
without arbitrating between them. Two cores would each believe they
won, and one value would be delivered twice, silently.

## Intended behavior

**One table, built at boot, mapping every address to itself.**

Nothing in the kernel changes meaning. A pointer holding a physical
address still holds that physical address. The table's whole purpose
here is its second column — the attributes.

```
       code says            table says              memory
    ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
    │  0x0040_0000 │ ─→ │ 0x0040_0000      │ ─→ │ 0x0040_0000  │
    └──────────────┘    │ Normal, cached,  │    └──────────────┘
                        │ inner-shareable  │
                        └──────────────────┘
                          the address is unchanged.
                          the attributes are the point.
```

**Two kinds of region, and getting the second kind wrong is loud.**

| region | attribute | why |
|---|---|---|
| RAM (the pool from 107) | Normal, write-back, inner-shareable | caches on; exclusives defined; the four cores keep one coherent view |
| device register windows | Device, non-gathering, non-reordering, no early ack | a write to the LED, USB, or display controller must reach the register, in order, exactly once |

*Inner-shareable* is the attribute doing the cross-core work. It tells
the hardware that these four cores must be kept agreeing about this
memory — a write on one is visible to the others, and the exclusive
monitor arbitrates between them. Mark RAM merely cacheable but not
shareable and each core caches happily in its own private world, which
is the same silent failure as before wearing a better disguise.

**What this buys, in one line each:**

- Compare-and-swap becomes a defined operation, so the claim in 209 is
  buildable at all.
- The caches come on, which the clock probe says is most of the ~35x.
- Unaligned accesses stop faulting, so ordinary C structs stop being a
  hazard.
- Phase 9 becomes a change to this table rather than new machinery: the
  same entries gain a per-app access attribute and a stray write starts
  trapping instead of quietly landing somewhere real.

**What it does not buy, and this is worth saying plainly.** With every
address mapped to itself and no per-app restriction, a box that
computes a wrong number still lands on real memory and the write
*succeeds*. There is no fault. The corruption surfaces later, somewhere
unrelated, as a wrong answer nobody can trace. Phase 2 cannot promise
otherwise; phase 9's protection work is exactly the machine that turns
that silence into a trap.

## Suggested implementation steps

1. Read the region list out of `docs/016-physical-memory-map.md` and
   emit the table from it, rather than hand-writing entries — the map
   document is the source and the table is generated from it.
2. Set up the memory-attribute register with the two attribute kinds
   above, write the table base into the translation-table-base
   register, then set the enable bit.
3. Clean and invalidate the data caches and the translation buffers
   before the enable, since anything cached from before the switch was
   cached under different rules.
4. A boot self-test in the manner of 108's: write a pattern, read it
   back, and separately confirm a device write still reaches its
   register — the LED is the cheapest possible witness, because if the
   device attributes came out wrong the LED simply stops responding.
5. Measure the same workload before and after and record the number,
   so 201a's remaining clock work is judged against a cached machine
   rather than against phase 1's.

## Open questions

- *Does this chip's exclusive monitor actually arbitrate across all
  four cores once memory is Normal inner-shareable?* It should — that
  is what the attribute means — but the entire engine rests on it and
  the failure is silent. A probe in the manner of `cpu-clock-recon`:
  two cores, a million compare-and-swap increments each, assert the
  total. It costs an afternoon and it converts an assumption into a
  measurement.
- *One instruction or a retry loop?* These cores are new enough to have
  single-instruction atomics — a compare-and-swap that is one
  instruction rather than a load-exclusive/store-exclusive pair that
  has to loop when it loses. The loop is portable and the instruction
  is faster under contention. Worth measuring on the claim path in 209
  rather than choosing now.
- *Where does the table itself live?* It has to be in memory that is
  mapped by the table it is part of, which is fine but wants stating in
  107's layout rather than being discovered.
- *Do the caches need flushing when a page changes hands between
  cores?* Under one coherent inner-shareable region, no. This becomes a
  real question in phase 9 when regions stop being uniform.

## Blocked by

107 (the region list), 108 (somewhere to put the table).

## Blocks

Every other issue in phase 2.

## Related

- [201a — Run the CPU at its rated speed](201a-cpu-clock-bring-up.md),
  whose own update concluded the caches were the headline and the
  clock the secondary lever. This is that headline.
- [016 — Physical memory map](../docs/016-physical-memory-map.md), the
  region list the table is generated from
- [007 — Memory model](../docs/007-memory-model.md), which said the MMU
  waits for phase 9 — true of translation, not of attributes
- [209 — The claim](209-the-readiness-check-and-the-claim.md), the
  first thing that cannot exist without this
