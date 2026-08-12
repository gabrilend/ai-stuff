# 209 — The readiness check and the claim

## Current behavior

**Values can sit in ports and nothing ever decides that a station may
run.**

## Intended behavior

This is the engine's one rule made real:

> A station runs when, and only when, every one of its input ports
> holds a value.

**Nothing polls.** The check runs as the tail end of a write, on
exactly one station — the one just written to. A station whose inputs
have not changed cannot have become ready, so there is nothing else to
look at. This is why there is no scheduler thread and no scan anywhere
in the engine: **the act of finishing is the act of scheduling.**

### The claim takes no lock

**Walk the ports in ascending order.** At each ring port, find a ready
cell and flip it to claimed. Statics are skipped — they are peeked,
never consumed, so there is nothing to take. Reach the end having
claimed one from every ring port and the run is real. Meet a ring port
with nothing ready, walk back releasing what you claimed, and give up.

```
   station with three ports.  two cores arrive at once.

   core 1:  port 0 ✓ claim   port 1 ✓ claim   port 2 ✓ claim  → run
   core 3:  port 0 ✗ nothing ready → give up, having taken nothing

   core 3 failed at the first step and released nothing,
   because both cores reached for port 0 first.
```

**The fixed order is the only subtle part, and it is what prevents
livelock.** Without it, two cores at a two-input station can each claim
one port, each fail on the other's port, each release, and retry into
the same interleaving forever — nobody blocked, nobody progressing, and
a complete input set sitting there the whole time. Lowest port first
means both reach for the same port, one wins outright, and the loser
fails at the first step having taken nothing.

```
   without a fixed order — the failure this avoids:

   core 1: claims port 0 ──→ finds port 1 taken ──→ releases ──┐
   core 3: claims port 1 ──→ finds port 0 taken ──→ releases ──┤
                                                               │
   ◀───────────────────── forever ────────────────────────────┘
```

**The claim is what lets two runs of one station happen at once.** By
the time a core has claimed its values, those values are its own —
copied out of the station into a task nothing else can see. A second
core arriving immediately after finds different values, claims those,
and the two never meet.

This is also why **a box may not remember anything between calls.** The
box function runs long after the claim, on whichever core picks the
task up, and two cores can be inside the same box function at the same
instant. Anything a box stored in itself would be shared between them.
Nothing enforces this. A box with a counter inside it will be wrong
under load and nothing will say so.

**Two things reach this check, and it answers identically to both.**

| what happened | reaches the check because |
|---|---|
| a value was delivered into a ring port | that is the tail of every delivery (211) |
| a value was written into a static port | a static write is an event; it runs the ordinary check |

The second is what starts a program at all. A station with only static
inputs is always ready, so writing one of its statics runs it. A chain
of stations wired through statics becomes a recalculation graph, and
the writes that build a program are the writes that set it going.

A write can never make something run that could not run anyway,
because the check it triggers is the ordinary one: an empty ring port
still answers no, and the engine will not invent a value for it.

**The walk is a dispatch table, not a chain of conditionals.** The
port's tag indexes into "is it filled?" and "give me a value". Adding a
fourth kind later should be a row, not a new branch in two functions
that have to be kept agreeing with each other.

## Suggested implementation steps

1. The two dispatch tables, one row per tag, with the *none* row
   answering "not filled" and never claimable. No row is an absence.
2. The check itself, called at the end of every write.
3. The claim: ascending order, claim-or-release, scanning from each
   port's bookmark. It writes into a values area the caller supplies,
   so this function allocates nothing.
4. Wire the static write to the same check, so there is one door rather
   than two.
5. A test with a three-input station fed in all six arrival orders,
   asserting exactly one run per complete set and none before the last
   value arrives.
6. A test with all four cores hammering one station, asserting the
   number of runs equals the number of complete input sets, with
   nothing claimed twice and nothing lost.
7. A test built to produce the livelock — two cores, a two-input
   station, values arriving continuously — run with the fixed order
   deliberately removed to confirm it can happen, then restored.

## Open questions

- *How long should a core retry after losing a claim?* It lost because
  another core is running that station right now, and the values it
  wanted are gone. Immediately trying again is right if more values are
  waiting and wasted if they are not. The cheapest answer is not to
  retry at all — the write that will complete the next set will run the
  check again — but that needs checking against the case where a core
  loses a race for a set that is still complete afterwards.
- *Does a station with no ring ports at all need a guard?* It is always
  ready, so every static write to it runs it. That is correct and it is
  also an unbounded amount of work if something writes that static in a
  loop. It is the map author's problem in the same way an infinite loop
  is, but the engine could at least be able to say which station is
  doing it.
- *Is one ordered walk enough when a station has many ports?* The walk
  is O(ports) with a scan inside each, run on every single delivery. For
  a two-input adder that is nothing. For a station with twenty inputs it
  is the hot path in the system. Measure at 215 before assuming.

## Blocked by

201, 207, 208.

## Blocks

210, 211.

## Related

- [208 — What an input port is](208-what-an-input-port-is.md), whose
  cells this claims
- [210 — The task](210-the-task.md), what the claimed values become
- [211 — The delivery walk](211-the-delivery-walk.md), which calls this
