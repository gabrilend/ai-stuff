# 039 — The rule six faces rely on

```meta
phase  | 5
issues | 506
```

The only blueprint in this project that specifies a **rule** rather than a
mechanism, and it is load-bearing out of all proportion to its length.

There is no operating system here, no lock manager, and nothing that would notice
a race. If this contract is wrong or unstated, the machine produces wrong answers
intermittently and there is no way to find out why.

## The five definitions

Everything below uses these and nothing else.

**A write** is complete when its data would be returned by a read issued
afterwards from the same face.

**A read** returns the data of some write to that location, and the contract says
which ones it may choose from.

**Release** is a write after which every write that face issued earlier is
complete.

**Acquire** is a read before which no read that face issues later may be
reordered.

**Two faces** are ordered with respect to each other **only** through a release
paired with an acquire on the same location.

## The guarantee table

| between | from the same face | from different faces |
|---|---|---|
| two reads | ordered | no guarantee |
| two writes | ordered | no guarantee |
| a read and a write | ordered | no guarantee |
| a release and a later acquire on it | — | **everything before the release is visible after the acquire** |

That is the whole contract. **There is no coherence**, stated explicitly so that
nobody assumes it, and no total store order.

## Why so little is enough

The traffic is almost entirely disjoint. Each face reads its own weights and
writes its own staging buffer. There are exactly **three** places where two faces
touch the same memory, and `072` must keep the same list:

**The staging handoff.** Stage *n* writes a buffer, then releases. Stage *n+1*
acquires, then reads. Two barriers, one buffer, no locks.

**The request region.** The host writes and face zero reads; face five writes and
the host reads. Same pattern.

**The pane.** The spout reads two mebibytes that a face may be writing.

A weak model with two explicit barriers is both easier to build and easier to
hold in your head than a strong one, and this blueprint makes that argument
rather than defaulting to the strong model out of caution.

## The third case, and the recommendation

`009` entry M2. Three possible contracts for the spout:

**Exclusion.** The pane may not move while writes are in flight. Simple, correct,
and stalls a token for as long as the read takes.

**Torn reads permitted.** The spout may see a mixture. Cheap, and pushes the
problem to whatever is on the other end — which since `069a` is a translation
unit with a buffer, is a real place rather than a void, but is still somewhere
that cannot tell old bits from new.

**Snapshot.** A version of the window is held stable. Costs storage and
complexity in the cage.

**Exclusion is recommended and this blueprint takes it.** A pane read is tens of
nanoseconds and a token is nine hundred microseconds, so the stall is parts per
hundred thousand, and it buys a contract a person can hold in their head. That
closes `009` entry M2.

## Symbols

```symbols
t_release     | ns | given | 12.0  | latency of a release: the time from issuing it to every earlier write being complete
t_acquire     | ns | given | 8.0   | latency of an acquire
n_share_site  | 1  | given | 3     | places in this machine where two faces touch the same memory
coherent      | 1  | given | 0     | whether hardware coherence exists. It does not, and this is written as a number so that a blueprint assuming otherwise fails rather than merely being wrong
t_write_max   | ns | derived | t_release + t_access + t_wait_face | the longest a write can be in flight: its own release, the array's access, and the worst the arbiter can make it wait. 033's brownout hold-up is judged against this. Written first with a hand conversion from seconds to nanoseconds, which turned nineteen nanoseconds into six and a half seconds
t_handoff     | ns | derived | t_release + t_acquire + 2 * t_link_rt  | a full stage handoff: release, the flag crossing to the next face, acquire, and the buffer read
t_pane_excl   | ns | derived | C_pane / B_core                        | how long the pane read excludes writes, which is the price of choosing exclusion
f_pane_stall  | 1  | derived | t_pane_excl / t_token                  | that price as a share of a token
```

## Constraints

```constraints
C-039-1 | t_handoff < t_stage / 1000     | a stage handoff must cost under a thousandth of a stage, or the two barriers show up in 080's model
C-039-2 | t_write_max < t_holdup * 1e9   | the longest write in flight must be shorter than the array rail's hold-up in 033. This is the constraint that stops a brownout leaving the model half written
C-039-3 | f_pane_stall < 0.001           | choosing exclusion for the pane must cost under a thousandth of a token. It is the arithmetic that makes the simple contract affordable, and if it failed the answer would be a snapshot rather than a torn read
C-039-4 | coherent == 0                  | there is no hardware coherence. Asserted as a value so that any blueprint deriving something from its existence fails outright rather than being quietly wrong
C-039-5 | n_share_site == 3              | three sharing sites, and 072's enumeration must find the same three. A site added to one blueprint and not the other is exactly the hole that produces intermittent wrong answers
```

## What is still open

**Training adds a fourth sharing site and this blueprint has not absorbed it.**
`076a`'s reverse staging buffers are stage *n+1* writing and stage *n* reading —
the same pattern in the other direction, so the same two barriers cover it — but
`n_share_site` still says three, and `C-039-5` will fail the day `076a` is
implemented rather than merely written.

**Nothing here is machine-checked.** The five definitions are prose. The
constraints check the latencies the contract implies, not the contract. There is
no way in this notation to state a memory model, and a machine-checkable one
would be worth more than everything else in this file.

**The host is outside the contract.** The request region is written by something
this design does not specify, over a link this design does not specify, and the
release-acquire pairing there is an assumption about a device in `069a` rather
than a rule anybody can enforce.
