# 910 — The cube as memory

Produces `src/069b-the-cube-as-memory.md`.

## Current behavior

Nothing. The idea arrived from outside the design: *it'd be RAM for a normal
computer to use and read from.*

## Intended behavior

**A mode in which an ordinary computer sees the cube's sixty-four gibibytes as
addressable memory**, reachable through the translation unit, while the cube goes
on generating.

This is the most useful thing anybody has suggested doing with the spout, and it
reframes the machine. A cube is not only an accelerator you send prompts to. It is
**a large, fast, self-populating block of memory that happens to be able to think
about its own contents.**

### What makes it plausible

Three properties the design already has, none of them added for this:

**The core is one flat address space** (`505`) with no caches above it and no
coherence to maintain (`506`). A host reading it does not have to be told about
anybody else's copy, because there are no copies.

**The pane is already a window.** `505`'s aliasing register says which two
mebibytes the spout currently sees, and moving it is one store. That is exactly
the mechanism a memory expander needs: a host request names an address, the window
moves, the pane crosses, the translation unit answers.

**The cube pays almost nothing.** A pane read costs the core fifty-four
nanoseconds and the spout one edge. Against a token's nine hundred microseconds,
serving a host is noise.

### What has to be added

**A request path back.** Everything in phase 9 is one-way. Memory needs the host
to say which address it wants, which means the translation unit must be able to
move the pane window — a small write into `505`'s control region, over the port
field or over a reverse channel on the spout. The blueprint must choose one.

**A latency budget.** Move the window, wait for the core read, cross the pane,
deskew, buffer, answer. Each of those is small; summed, it is likely to be
**hundreds of nanoseconds**, which is far slower than the host's own memory and
comparable to a fabric-attached memory expander. So the cube is not main memory.
It is a large second tier, and the blueprint must position it honestly as one.

**An access rule against the generator.** The host reading a region the faces are
writing is exactly `506`'s third sharing case. `506` recommends exclusion for the
spout; a host that can ask at any time makes exclusion expensive. The blueprint
must either restrict host reads to regions the model is not writing — the weight
region is read-only during generation and is thirty-five of the sixty-four
gigabytes — or accept torn reads and say so.

**Restricting to the weight region is the good answer**: it is most of the
capacity, it is genuinely immutable while a model is loaded, and it needs no
locking at all.

### What it is actually good for

The blueprint should be specific rather than gesturing, because "it can be RAM" is
a claim that invites the wrong comparison:

- **Loading a model into the cube from the host side**, by writing rather than by
  streaming from storage lines. Turns a thirty millisecond load into a host-paced
  one, but removes the need for eighty drives.
- **Reading the model back out**, for checkpointing after `1107`'s adapter
  training. This is the one that matters if training is used.
- **Sharing a model between a cube and a host process** that wants to inspect it.
- **A second cube reading the first's weights**, which is the ganging case without
  a ganging protocol.

## Symbols this must publish

Host-visible capacity and which regions are exposed. Access granularity. Request
path and its latency. Total read latency, itemised. Sustained host-side bandwidth.
Cube-side cost per host access, in core nanoseconds and in tokens delayed. The
access rule and the regions it permits.

## Constraints this must assert

- Cube-side cost per host access at the maximum host rate is under a stated
  fraction of a token time, so serving memory never visibly slows generation.
- Exposed regions are disjoint from anything the faces write during generation,
  under the chosen access rule.
- Host-visible capacity plus everything else mapped in `505` is within usable
  capacity.
- Read latency is reported, and the blueprint states it is a second tier rather
  than main memory. A documentation constraint, checked by `098` finding the
  sentence.

## Suggested implementation steps

1. Choose the request path — port field or reverse spout channel — and price both.
2. Build the latency budget term by term.
3. Choose the weight-region-only access rule and show it needs no locking.
4. Derive the cube-side cost and assert it is invisible.
5. Write the four uses concretely.

## Blocks

`1301`, `1303`.

## Blocked by

`505`, `506`, `901`, `909`.

## Related documents

`007`. `009` entries O1 and B3, both of which this ticket bears on.
