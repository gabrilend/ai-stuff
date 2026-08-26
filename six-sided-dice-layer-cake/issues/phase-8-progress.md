# Phase 8 — The Feed: progress

**How a model gets into the cube. Complete.**

| ticket | blueprint | state |
|---|---|---|
| `801` | `056-port-field` | done |
| `802` | `057-storage-line-physical` | done |
| `803` | `058-weight-format-on-media` | done |
| `804` | `059-residency-and-paging` | done |
| `805` | `060-prefetch-and-double-buffer` | done |
| `806` | `061-feed-bandwidth` | done |

**Two hundred and ninety-one constraints hold across fifty-two blueprints.**
Fifty wait on phases 9 through 12, nearly all of them for the reference model in
`078`.

## The sentence that sets the standard

*After the load, no weight a face reads comes from a drive.*

Everything in `057` follows from it. A line that takes thirty milliseconds
instead of six is a line nobody notices; a line that costs two hundred watts is
one everybody notices. So the drive count is a **deployment table with a load
time attached** rather than a requirement, and the lines are sized for cost and
heat.

## The failure that produced a real correction

The storage lines draw fifty-one watts while loading against a ten watt port
allocation. They do not fit in the steady budget and **should not have to** —
loading runs them flat out for tens of milliseconds and then they are idle until
the machine is next power-cycled.

The budget now carries a transient allowance beside the steady one, and both
things that break the steady figure — a model load, and a spout pane — are judged
as **energies against thermal mass** rather than as powers against coolant. That
is the same treatment `026` gave the spout in phase 3, arrived at independently
from the other end.

## Two absences worth naming

**A cache with no cache logic** (`059`). The slice has no tags, no comparators
and no victim selection, because the walk order is known before the token starts
and there is nothing to choose between. Asserted as a value so that adding a
policy has to say what it would be choosing.

**A prefetcher with no prediction** (`060`). Every address is known before the
token starts. What it does have to get right is the *lead*, computed against a
face's contended share rather than the whole core — which is the mistake that
makes a prefetcher work in isolation and stall whenever the machine is busy, and
is asserted in the obvious direction on purpose.

## Three guesses stacked

`060`'s stall probability, `047`'s bank conflict probability, and `038`'s
interleaving — which is a stride rather than an analysis. None is derived from
the others, and **`049`'s counters are the only thing that will ever settle
them**.

The consequence is that the number deciding `009` entry F2 does not exist:
whether a third slice buffer is worth a larger die turns on how often a stall
actually happens with two.

## What is still open

**No physical layer is named for the storage line** (`057`). The blueprint says
to adopt an existing standard and does not say which, so its rate, reach and
energy per bit are plausible rather than sourced.

**Nothing describes how the media file is produced** (`058`). Something outside
this machine quantises the model, fits the expansion tables, computes the
rotations and writes the layout. **It is the only substantial piece of software
the design assumes and does not specify**, and `085` needs it on day one.

**The storage line controller is not designed** (`057`) — the only logic in the
machine that speaks somebody else's protocol.

**The uneven stage is not modelled** (`061`). Two faces carry extra work and the
margins here are checked against an average layer.

**The fine zone's cost is named and not quantified** (`056`). A bondable pitch on
all six faces when five will never use it is a yield term `083` should carry.
