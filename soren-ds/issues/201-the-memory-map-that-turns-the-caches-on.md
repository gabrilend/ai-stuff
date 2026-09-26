# 201 — The memory map that turns the caches on

## Current behavior

**Written, compiled, unverified on hardware.**
`src/device/044-identity-map.c` builds one level-1 translation table of
one-gigabyte blocks mapping every address to itself: gigabytes 0–2 are
normal, write-back, inner-shareable RAM; gigabyte 3 (every peripheral
window, per `docs/016-physical-memory-map.md`) is device memory, never
executable; everything above is invalid, so a stray access faults
loudly. `mmu_enable_on_this_core` loads MAIR, TCR and TTBR0 for
exception level 1, invalidates the translation buffers and instruction
cache, and sets the translation, data-cache and instruction-cache bits.
Every core calls it for itself (043-cores.s does, for the secondary
cores).

Nothing calls it on the ordinary boot. The self-test, the before/after
measurement, and the cross-core compare-and-swap probe described below
are still to be run on the device.

On the laptop twin the question does not arise: the host's memory is
already normal and coherent, which is why the whole engine could be
built and tested there first.

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

### Proposed answers (UNVERIFIED)

1. *Does the exclusive monitor arbitrate across all four cores?* Assumed
   yes; the probe proposed above is the check. The twin's claim test
   (053) is the same property on the laptop and passes: four cores
   spraying one adder produced exactly as many runs as complete pairs.
2. *One instruction or a retry loop?* The kernel is built for the
   Cortex-A55 (`-mcpu=cortex-a55`), so the compiler already emits the
   single-instruction atomics. Keep that; measure against the loop only
   if a problem appears.
3. *Where does the table live?* In the kernel image's own data — it is
   `level1[]` in 044-identity-map.c, 4 KB aligned, and inside RAM the
   table maps as normal. Answered in the code's comment.
4. *Flush when a page changes hands?* No, under one coherent region, as
   the question itself says; revisit in phase 9.
5. *(new)* **Which exception level does the kernel run at?** The table
   is written for EL1 because `001-boot.s` already writes `vbar_el1`. If
   the bootloader hands over at EL2, both are configuring the wrong
   level. The first hardware run should read `CurrentEL` and print it.

## Blocked by

107 (the region list), 108 (somewhere to put the table), 200 (the
platform seam the device half answers).

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
