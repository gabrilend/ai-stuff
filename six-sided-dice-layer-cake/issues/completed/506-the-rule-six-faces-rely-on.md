# 506 — The rule six faces rely on

Produces `src/039-core-ordering-model.md`.

## Current behavior

**Done, and it closes `009` entry M2.** `src/039-core-ordering-model.md` exists
with five definitions and one table, which is the whole contract.

There is no coherence, and that is written as a value rather than left unsaid, so
that any blueprint deriving something from its existence fails outright instead
of being quietly wrong. There are exactly three places where two faces touch the
same memory, and a constraint requires `072`'s enumeration to find the same
three — a site added to one and not the other is precisely the hole that produces
intermittent wrong answers with nothing able to notice.

The pane question is closed in favour of exclusion, with the arithmetic that
makes it affordable: a pane read is tens of nanoseconds against a token's nine
hundred microseconds, so the simple contract costs parts per hundred thousand.

**Training will break `C-039-5`.** `076a`'s reverse staging buffers are a fourth
sharing site — the same pattern in the other direction, so the same barriers
cover it — but the count still says three and the constraint will fail the day
that blueprint is implemented rather than merely written. Which is the right
behaviour.

**Nothing here is machine-checked.** The five definitions are prose and the
constraints check the latencies the contract implies, not the contract.

## Intended behavior

**The memory ordering contract: what a face may assume about the order in which its
writes become visible to the other five.**

This is the only blueprint in the project that specifies a *rule* rather than a
mechanism, and it is load-bearing out of proportion to its length. There is no
operating system here, no lock manager, and nothing that would notice a race. If
the contract is wrong or unstated, the machine produces wrong answers
intermittently and there is no way to find out why.

### What the machine actually needs

Very little, which is the good news. The traffic pattern is almost entirely
disjoint: each face reads its own weights and writes its own staging buffer. There
are exactly three places where two faces touch the same memory:

- **The staging handoff.** Stage *n* writes a buffer and then sets a flag. Stage
  *n+1* reads the flag and then the buffer. This needs a **release** on the write
  side and an **acquire** on the read side, and nothing more.
- **The request region.** The host writes, face zero reads; face five writes, the
  host reads. Same pattern.
- **The pane.** The spout reads two mebibytes that a face may be writing.

So the contract can be weak — no total store order, no coherent caches, no
snooping — provided the two barrier operations exist and are cheap. **A weak model
with two explicit barriers is both easier to build and easier to reason about than
a strong one**, and the blueprint should make that argument rather than defaulting
to the strong model out of caution.

### The third case is the hard one

The spout reading a region a face is writing. Three possible contracts:

- **Exclusion.** The pane may not move while writes are in flight. Simple,
  correct, and stalls a token for as long as the read takes.
- **Torn reads permitted.** The spout may see a mixture of old and new. Cheap, and
  pushes the problem to whatever is on the other end — which, per `009` entry O1,
  is not designed, so this is currently pushing the problem into a void.
- **Snapshot.** A version of the window is held stable while it is read. Costs
  storage and complexity in the cage.

`009` entry M2 carries this and it must be closed here. **The recommendation is
exclusion**, because a pane read is fifty-four nanoseconds and a token is nine
hundred microseconds, so the stall is four parts in a hundred thousand and buys a
contract a person can hold in their head.

### What must be stated precisely

The blueprint must define, in the same terms every time: what a write means, what
a read means, what release and acquire mean, what is guaranteed between two
operations from the same face, and what is guaranteed between operations from
different faces. Five short definitions and one table. Anything vaguer than that
is not a contract.

It must also state the **longest in-flight write**, because `406`'s brownout
handling has to hold the array rail up for at least that long or writes tear.

## Symbols this must publish

Longest in-flight write time. Barrier latency for release and for acquire. Staging
handoff round-trip. The pane exclusion window. Whether coherence exists, as an
explicit false.

## Constraints this must assert

- Barrier latency is under a stated fraction of `704`'s per-stage budget, or the
  handoff costs more than it should.
- Longest in-flight write is under `406`'s array hold-up time.
- Pane exclusion window is under a stated fraction of a token time.

## Suggested implementation steps

1. Write the five definitions and the guarantee table. Nothing else in the
   blueprint matters as much as their precision.
2. Enumerate the three sharing sites and show that the two barriers cover them.
3. Close `009` entry M2 by choosing exclusion, with the arithmetic that justifies
   it.
4. Derive the longest in-flight write and hand it to `406`.
5. State explicitly that there is no coherence, so nobody assumes it.

## Blocks

`406`, `703`, `704`, `705`, `901`.

## Blocked by

`504`, `505`.

## Related documents

`003` for the handoff that depends on this. `009` entries M2 and S1.
