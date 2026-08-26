# 072 — Six faces agreeing what cycle it is

```meta
phase  | 10
issues | 1003
```

## The claim

**Faces need to agree about order, not about time.**

`039`'s contract is the whole of what one face may assume about another, and it is
expressed in releases and acquires through memory — not in cycles, not in edges,
and not in any shared notion of *now*. Nothing in this machine ever asks what face
three is doing this cycle.

So a domain crossing at each face's radial interface, plus `039`'s two barriers,
is sufficient — and this blueprint's job is to establish that **rigorously**, by
enumerating every place two faces interact and showing each is covered.

```drawing
every site where two faces touch the same memory [not-dimensioned]

   1  the six staging buffers          release / acquire
   2  the request region               release / acquire
   3  the pane                         039's exclusion rule
   -  the arbiter                      one clock domain; not a crossing at all
   -  the reverse staging buffers      a fourth, when 076a is implemented
```

If the enumeration is complete, mesochronous operation is enough and a great deal
of power is saved. **If it is not, the machine produces intermittent wrong answers
with nothing able to notice** — which is why `C-072-1` requires this list and
`039`'s to be the same length.

## The crossing itself

Each face's link to the cage crosses from the face's clock to the cage's.
Standard apparatus, and the blueprint must **derive the failure rate rather than
assume it is negligible**: at tens of terabytes a second crossing six times,
*negligible* is a number, and it belongs beside `040`'s soft error rate when
`086` adds them up.

## What still needs a common time

Two things, and both are slow.

**Bring-up**, which has to get all six faces into a known state together, once.
**Telemetry**, because `049`'s counters are far more useful if they can be
compared across faces — at microsecond resolution, not picosecond.

A slow free-running counter distributed from the auxiliary domain serves both and
costs almost nothing. **It is not a clock**, and the blueprint says so plainly, so
that nobody builds a timing path on it.

## Symbols

```symbols
n_sync_stage  | 1 | given | 3        | flip-flop stages in a synchroniser
t_setup_ff    | ps | given | 15.0    | setup time of one
tau_meta      | ps | given | 8.0     | metastability resolution time constant of the process
t_meta_0      | s | measured | 1.0e-12 | the metastability window: how wide a slice of each clock edge can put a flip-flop into an undecided state
n_cross_site  | 1 | given | 3        | places two faces interact through memory, excluding the arbiter which is inside one domain. Three today; the reverse staging buffers make it four the day 076a is implemented, and 039's count moves with it
w_timebase    | bit | given | 52     | width of the free-running timebase counter. Forty-eight wraps in under nine years, which is inside the life the machine is built for -- and two counters compared across faces after a wrap can disagree about which came first
f_timebase    | MHz | given | 1.0    | its rate: microsecond resolution, deliberately far below any clock so it cannot be mistaken for one

t_resolve     | ps | derived | n_sync_stage * t_cycle_face - t_setup_ff | time a synchroniser gives metastability to resolve
mtbf_sync     | s | derived | exp(t_resolve / tau_meta) / (f_face * f_core * t_meta_0) | mean time between synchroniser failures at one crossing: the two clocks' rates and the window between them, against the time the synchroniser gives metastability to resolve
mtbf_all      | s | derived | mtbf_sync / (n_face * 2)                | and across all six links in both directions
t_cross_face  | ps | derived | n_sync_stage * t_cycle_face            | latency a domain crossing adds, which lands in 053's stage budget
t_timebase_wrap | s | derived | 2^(w_timebase / b1) / f_timebase      | how long the shared timebase runs before wrapping
res_timebase  | s | derived | 1 / f_timebase                          | its resolution
f_cross_stage | 1 | derived | t_cross_face / t_stage                  | the crossing's cost as a share of a pipeline stage
```

## Constraints

```constraints
C-072-1 | n_cross_site == n_share_site | this enumeration and 039's must find the same number of places two faces touch. A site added to one blueprint and not the other is exactly the hole that produces intermittent wrong answers, and there is nothing else in the machine that would catch it
C-072-2 | mtbf_all > t_life_seconds    | synchroniser failure across all six links in both directions must be rarer than the machine's whole life. At these rates *negligible* is a number and it belongs beside 040's soft error rate rather than being asserted
C-072-3 | f_cross_stage < 0.001        | a domain crossing must cost under a thousandth of a pipeline stage
C-072-4 | t_timebase_wrap > t_life_seconds | the shared timebase must not wrap within the machine's life, or two counters compared across faces can disagree about which came first
C-072-5 | res_timebase > t_cycle_face * 100 | the timebase must be far coarser than a clock, so that nobody mistakes it for one and builds a timing path on it
C-072-6 | n_sync_stage >= 2            | a synchroniser needs at least two stages; one is a flip-flop
```

## What is still open

**The enumeration is checked by count and not by name.** `C-072-1` requires four
here and four in `039`. It cannot require that they are the *same* four, because
the notation holds numbers and not lists — so two blueprints could each name four
different sites and pass. That is the weakest link in the argument that
mesochronous operation is safe.

**Training will change the count to five** and both blueprints must move together.
`039` already records that `C-039-5` will fail the day `076a` is implemented; this
one will fail with it, which is the right behaviour and worth knowing in advance.
